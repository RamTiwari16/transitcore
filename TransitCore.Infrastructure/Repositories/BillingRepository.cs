using System.Data;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class BillingRepository : IBillingService
{
    private readonly SqlDataAccess _db;

    public BillingRepository(SqlDataAccess db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<CustomerDto>> GetCustomersAsync(bool activeOnly, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@ActiveOnly", activeOnly) };
        var table = await _db.QueryProcedureAsync("billing.usp_GetCustomers", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new CustomerDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Code = row["Code"].ToString() ?? string.Empty,
                Name = row["Name"].ToString() ?? string.Empty,
                IsActive = Convert.ToBoolean(row["IsActive"])
            })
            .ToList();
    }

    public async Task<int> CreateCustomerAsync(CreateCustomerRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("billing.usp_InsertCustomer", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<IReadOnlyList<InvoiceDto>> GetInvoicesAsync(InvoiceFilterRequest filter, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@CustomerId", (object?)filter.CustomerId ?? DBNull.Value),
            new SqlParameter("@StatusId", (object?)filter.StatusId ?? DBNull.Value)
        };

        var table = await _db.QueryProcedureAsync("billing.usp_GetInvoices", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>().Select(MapInvoice).ToList();
    }

    public async Task<InvoiceDetailDto?> GetInvoiceByIdAsync(int invoiceId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@InvoiceId", invoiceId) };
        var dataSet = await _db.QueryProcedureMultipleAsync("billing.usp_GetInvoiceById", parameters, cancellationToken);

        if (dataSet.Tables.Count == 0 || dataSet.Tables[0].Rows.Count == 0)
            return null;

        var invoice = MapInvoice(dataSet.Tables[0].Rows[0]);

        var lines = dataSet.Tables.Count > 1
            ? dataSet.Tables[1].Rows.Cast<DataRow>().Select(row => new InvoiceLineDto
            {
                Id = Convert.ToInt32(row["Id"]),
                ShipmentId = row["ShipmentId"] == DBNull.Value ? null : Convert.ToInt32(row["ShipmentId"]),
                Description = row["Description"].ToString() ?? string.Empty,
                Quantity = Convert.ToDecimal(row["Quantity"]),
                UnitPrice = Convert.ToDecimal(row["UnitPrice"]),
                LineTotal = Convert.ToDecimal(row["LineTotal"])
            }).ToList()
            : new List<InvoiceLineDto>();

        return new InvoiceDetailDto
        {
            Id = invoice.Id,
            InvoiceNo = invoice.InvoiceNo,
            CustomerId = invoice.CustomerId,
            CustomerName = invoice.CustomerName,
            InvoiceDate = invoice.InvoiceDate,
            DueDate = invoice.DueDate,
            Subtotal = invoice.Subtotal,
            TaxAmount = invoice.TaxAmount,
            TotalAmount = invoice.TotalAmount,
            StatusId = invoice.StatusId,
            StatusName = invoice.StatusName,
            Lines = lines
        };
    }

    public async Task<int> CreateInvoiceAsync(CreateInvoiceRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var linesTable = new DataTable();
        linesTable.Columns.Add("ShipmentId", typeof(int));
        linesTable.Columns.Add("Description", typeof(string));
        linesTable.Columns.Add("Quantity", typeof(decimal));
        linesTable.Columns.Add("UnitPrice", typeof(decimal));
        linesTable.Columns.Add("LineTotal", typeof(decimal));

        foreach (var line in request.Lines)
        {
            var row = linesTable.NewRow();
            row["ShipmentId"] = (object?)line.ShipmentId ?? DBNull.Value;
            row["Description"] = line.Description;
            row["Quantity"] = line.Quantity;
            row["UnitPrice"] = line.UnitPrice;
            row["LineTotal"] = line.Quantity * line.UnitPrice;
            linesTable.Rows.Add(row);
        }

        var linesParameter = new SqlParameter("@Lines", SqlDbType.Structured)
        {
            TypeName = "billing.InvoiceLineType",
            Value = linesTable
        };

        var parameters = new[]
        {
            new SqlParameter("@InvoiceNo", request.InvoiceNo),
            new SqlParameter("@CustomerId", request.CustomerId),
            new SqlParameter("@InvoiceDate", request.InvoiceDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@DueDate", request.DueDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@TaxAmount", request.TaxAmount),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@CreatedBy", createdBy),
            linesParameter
        };

        var newId = await _db.ExecuteScalarProcedureAsync("billing.usp_InsertInvoice", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<InvoiceSummaryDto> GetInvoiceSummaryAsync(DateOnly fromDate, DateOnly toDate, int? customerId, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@FromDate", fromDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@ToDate", toDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@CustomerId", (object?)customerId ?? DBNull.Value)
        };

        var table = await _db.QueryProcedureAsync("billing.usp_GetInvoiceSummary", parameters, cancellationToken);

        if (table.Rows.Count == 0)
            return new InvoiceSummaryDto();

        var row = table.Rows[0];
        return new InvoiceSummaryDto
        {
            InvoiceCount = Convert.ToInt32(row["InvoiceCount"]),
            TotalInvoiced = Convert.ToDecimal(row["TotalInvoiced"]),
            TotalPaid = Convert.ToDecimal(row["TotalPaid"]),
            TotalOutstanding = Convert.ToDecimal(row["TotalOutstanding"])
        };
    }

    private static InvoiceDto MapInvoice(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        InvoiceNo = row["InvoiceNo"].ToString() ?? string.Empty,
        CustomerId = Convert.ToInt32(row["CustomerId"]),
        CustomerName = row["CustomerName"].ToString() ?? string.Empty,
        InvoiceDate = DateOnly.FromDateTime(Convert.ToDateTime(row["InvoiceDate"])),
        DueDate = DateOnly.FromDateTime(Convert.ToDateTime(row["DueDate"])),
        Subtotal = Convert.ToDecimal(row["Subtotal"]),
        TaxAmount = Convert.ToDecimal(row["TaxAmount"]),
        TotalAmount = Convert.ToDecimal(row["TotalAmount"]),
        StatusId = Convert.ToInt32(row["StatusId"]),
        StatusName = row["StatusName"].ToString() ?? string.Empty
    };
}
