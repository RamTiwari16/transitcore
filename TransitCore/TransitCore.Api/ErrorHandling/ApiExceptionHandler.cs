using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Models;

namespace TransitCore.Api.ErrorHandling;

// Turns database rule violations (duplicates, CHECK/FK constraints, THROW 5xxxx
// business errors) into 4xx ApiResponse bodies whose message the UI toasts,
// instead of an opaque 500.
public sealed partial class ApiExceptionHandler(ILogger<ApiExceptionHandler> logger, IHostEnvironment environment) : IExceptionHandler
{
    private const string GenericMessage = "Something went wrong on our end. Please try again.";

    private static readonly Dictionary<string, string> ConstraintMessages = new(StringComparer.OrdinalIgnoreCase)
    {
        ["UQ_ProofOfDelivery_TripId"] = "Proof of delivery has already been recorded for this trip.",
        ["UQ_UserBranches_OnePrimaryPerUser"] = "A user can only have one primary branch.",
        ["UQ_ConsignmentNotes_ShipmentId"] = "This shipment already has a consignment note.",
        ["CK_Vehicles_ManufactureYear"] = "Manufacture year must be between 1980 and 2100.",
        ["CK_MaintenanceRecords_Cost"] = "Maintenance cost can't be negative.",
        ["CK_FuelLogs_Liters"] = "Fuel litres can't be negative.",
        ["CK_FuelLogs_Cost"] = "Fuel cost can't be negative.",
        ["CK_DriverAssignments_Dates"] = "End date can't be before the start date.",
        ["CK_Trips_ScheduledWindow"] = "Scheduled arrival can't be before scheduled departure.",
        ["CK_ShipmentItems_Quantity"] = "Item quantity must be greater than zero.",
        ["CK_RateCards_EffectiveWindow"] = "Effective To can't be before Effective From.",
        ["CK_Invoices_DueDate"] = "Due date can't be before the invoice date.",
        ["CK_Invoices_Amounts"] = "Invoice totals can't be negative - check the discount isn't larger than subtotal plus tax.",
        ["CK_InvoiceLines_Quantity"] = "Line quantity must be greater than zero.",
        ["CK_Payments_Amount"] = "Payment amount must be greater than zero.",
        ["CK_TripExpenses_Amount"] = "Expense amount can't be negative.",
        ["CK_TripAdvances_Amount"] = "Advance amount can't be negative.",
    };

    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var (statusCode, message) = exception is SqlException sqlException
            ? Map(sqlException)
            : (StatusCodes.Status500InternalServerError, GenericMessage);

        if (statusCode >= StatusCodes.Status500InternalServerError)
        {
            logger.LogError(exception, "Unhandled exception for {Method} {Path}", httpContext.Request.Method, httpContext.Request.Path);
            if (environment.IsDevelopment())
                message = $"{message} ({exception.Message})";
        }

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(ApiResponse<string>.Fail(message), cancellationToken);
        return true;
    }

    private static (int StatusCode, string Message) Map(SqlException exception) => exception.Number switch
    {
        2627 or 2601 => (StatusCodes.Status409Conflict, DuplicateMessage(exception.Message)),
        547 => ConstraintConflict(exception.Message),
        515 => (StatusCodes.Status400BadRequest, MissingValueMessage(exception.Message)),
        >= 50000 => (StatusCodes.Status400BadRequest, exception.Message),
        _ => (StatusCodes.Status500InternalServerError, GenericMessage),
    };

    // "Violation of UNIQUE KEY constraint 'UQ_Invoices_InvoiceNo'. ... The duplicate key value is (INV-001)."
    private static string DuplicateMessage(string sqlMessage)
    {
        var name = UniqueNameRegex().Match(sqlMessage);
        if (name.Success && ConstraintMessages.TryGetValue(name.Groups[1].Value, out var known))
            return known;

        var value = DuplicateValueRegex().Match(sqlMessage);
        var field = name.Success ? Humanize(name.Groups[1].Value.Split('_')[^1]) : null;

        return (field, value.Success) switch
        {
            (not null, true) => $"{field} \"{value.Groups[1].Value}\" already exists.",
            (null, true) => $"\"{value.Groups[1].Value}\" already exists.",
            _ => "This record already exists.",
        };
    }

    // "The INSERT statement conflicted with the CHECK constraint "CK_Invoices_DueDate". ..."
    private static (int StatusCode, string Message) ConstraintConflict(string sqlMessage)
    {
        var match = ConflictRegex().Match(sqlMessage);
        if (!match.Success)
            return (StatusCodes.Status400BadRequest, "The request conflicts with existing data.");

        var (kind, name) = (match.Groups[1].Value, match.Groups[2].Value);
        return kind switch
        {
            "CHECK" => (StatusCodes.Status400BadRequest,
                ConstraintMessages.TryGetValue(name, out var known) ? known : $"One of the values isn't allowed ({name})."),
            "REFERENCE" => (StatusCodes.Status409Conflict, "This record is still used by other records, so it can't be removed."),
            _ => (StatusCodes.Status400BadRequest, "One of the selected items no longer exists. Refresh the page and try again."),
        };
    }

    // "Cannot insert the value NULL into column 'Code', table 'TransitCoreDb.lookup.Branches'; ..."
    private static string MissingValueMessage(string sqlMessage)
    {
        var column = NullColumnRegex().Match(sqlMessage);
        return column.Success ? $"{Humanize(column.Groups[1].Value)} is required." : "A required value is missing.";
    }

    private static string Humanize(string pascalCase) => WordBoundaryRegex().Replace(pascalCase, " ");

    [GeneratedRegex(@"(?:constraint|index) '([^']+)'", RegexOptions.IgnoreCase)]
    private static partial Regex UniqueNameRegex();

    [GeneratedRegex(@"The duplicate key value is \((.*)\)\.")]
    private static partial Regex DuplicateValueRegex();

    [GeneratedRegex(@"conflicted with the (CHECK|FOREIGN KEY|REFERENCE) constraint ""([^""]+)""")]
    private static partial Regex ConflictRegex();

    [GeneratedRegex(@"Cannot insert the value NULL into column '([^']+)'")]
    private static partial Regex NullColumnRegex();

    [GeneratedRegex(@"(?<=[a-z])(?=[A-Z])")]
    private static partial Regex WordBoundaryRegex();
}
