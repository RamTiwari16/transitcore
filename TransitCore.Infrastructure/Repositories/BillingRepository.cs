using System.Data;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Application.Services;
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

        return table.Rows.Cast<DataRow>().Select(MapCustomer).ToList();
    }

    public async Task<int> CreateCustomerAsync(CreateCustomerRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@CreditLimit", (object?)request.CreditLimit ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("billing.usp_InsertCustomer", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<CustomerDto?> GetCustomerByIdAsync(int customerId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@CustomerId", customerId) };
        var table = await _db.QueryProcedureAsync("billing.usp_GetCustomerById", parameters, cancellationToken);

        return table.Rows.Count == 0 ? null : MapCustomer(table.Rows[0]);
    }

    public async Task<bool> UpdateCustomerAsync(UpdateCustomerRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@CustomerId", request.CustomerId),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@IsActive", request.IsActive),
            new SqlParameter("@CreditLimit", (object?)request.CreditLimit ?? DBNull.Value),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("billing.usp_UpdateCustomer", parameters, cancellationToken);

        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<CustomerOutstandingBalanceDto> GetCustomerOutstandingBalanceAsync(int customerId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@CustomerId", customerId) };
        var table = await _db.QueryProcedureAsync("billing.usp_GetCustomerOutstandingBalance", parameters, cancellationToken);

        if (table.Rows.Count == 0)
            return new CustomerOutstandingBalanceDto { CustomerId = customerId };

        return new CustomerOutstandingBalanceDto
        {
            CustomerId = customerId,
            OutstandingBalance = Convert.ToDecimal(table.Rows[0]["OutstandingBalance"])
        };
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
                ShipmentChargeId = row["ShipmentChargeId"] == DBNull.Value ? null : Convert.ToInt32(row["ShipmentChargeId"]),
                Description = row["Description"].ToString() ?? string.Empty,
                Quantity = Convert.ToDecimal(row["Quantity"]),
                UnitPrice = Convert.ToDecimal(row["UnitPrice"]),
                LineTotal = Convert.ToDecimal(row["LineTotal"])
            }).ToList()
            : new List<InvoiceLineDto>();

        var payments = dataSet.Tables.Count > 2
            ? dataSet.Tables[2].Rows.Cast<DataRow>().Select(row => new PaymentDto
            {
                Id = Convert.ToInt32(row["Id"]),
                PaymentDate = DateOnly.FromDateTime(Convert.ToDateTime(row["PaymentDate"])),
                Amount = Convert.ToDecimal(row["Amount"]),
                Method = row["Method"].ToString() ?? string.Empty,
                ReferenceNo = row["ReferenceNo"] as string
            }).ToList()
            : new List<PaymentDto>();

        return new InvoiceDetailDto
        {
            Id = invoice.Id,
            InvoiceNo = invoice.InvoiceNo,
            CustomerId = invoice.CustomerId,
            CustomerName = invoice.CustomerName,
            InvoiceDate = invoice.InvoiceDate,
            DueDate = invoice.DueDate,
            Subtotal = invoice.Subtotal,
            DiscountAmount = invoice.DiscountAmount,
            TaxAmount = invoice.TaxAmount,
            TotalAmount = invoice.TotalAmount,
            StatusId = invoice.StatusId,
            StatusName = invoice.StatusName,
            PaidAmount = invoice.PaidAmount,
            Lines = lines,
            Payments = payments
        };
    }

    public async Task<int> CreateInvoiceAsync(CreateInvoiceRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var linesTable = new DataTable();
        linesTable.Columns.Add("ShipmentId", typeof(int));
        linesTable.Columns.Add("ShipmentChargeId", typeof(int));
        linesTable.Columns.Add("Description", typeof(string));
        linesTable.Columns.Add("Quantity", typeof(decimal));
        linesTable.Columns.Add("UnitPrice", typeof(decimal));
        linesTable.Columns.Add("LineTotal", typeof(decimal));

        foreach (var line in request.Lines)
        {
            var row = linesTable.NewRow();
            row["ShipmentId"] = (object?)line.ShipmentId ?? DBNull.Value;
            // This freeform path (manual Description/Qty/UnitPrice entry)
            // never links to a ShipmentCharge - that's what
            // CreateInvoiceFromChargesAsync/usp_InsertInvoiceFromCharges is
            // for. Column still has to be present since it's part of the
            // TVP's shape now.
            row["ShipmentChargeId"] = DBNull.Value;
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
            new SqlParameter("@DiscountAmount", request.DiscountAmount),
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

    // ---- Rate cards ----

    public async Task<IReadOnlyList<RateCardDto>> GetRateCardsAsync(int? customerId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@CustomerId", (object?)customerId ?? DBNull.Value) };
        var table = await _db.QueryProcedureAsync("billing.usp_GetRateCards", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>().Select(MapRateCard).ToList();
    }

    public async Task<int> CreateRateCardAsync(CreateRateCardRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@CustomerId", (object?)request.CustomerId ?? DBNull.Value),
            new SqlParameter("@OriginCityId", (object?)request.OriginCityId ?? DBNull.Value),
            new SqlParameter("@DestinationCityId", (object?)request.DestinationCityId ?? DBNull.Value),
            new SqlParameter("@RatePerKg", request.RatePerKg),
            new SqlParameter("@RatePerKm", request.RatePerKm),
            new SqlParameter("@Basis", request.Basis),
            new SqlParameter("@RatePerTrip", (object?)request.RatePerTrip ?? DBNull.Value),
            new SqlParameter("@RatePerTon", (object?)request.RatePerTon ?? DBNull.Value),
            new SqlParameter("@RatePerPackage", (object?)request.RatePerPackage ?? DBNull.Value),
            new SqlParameter("@MinimumChargeableWeightKg", (object?)request.MinimumChargeableWeightKg ?? DBNull.Value),
            new SqlParameter("@LoadingRatePerEvent", (object?)request.LoadingRatePerEvent ?? DBNull.Value),
            new SqlParameter("@UnloadingRatePerEvent", (object?)request.UnloadingRatePerEvent ?? DBNull.Value),
            new SqlParameter("@DetentionFreeHours", (object?)request.DetentionFreeHours ?? DBNull.Value),
            new SqlParameter("@DetentionRatePerHour", (object?)request.DetentionRatePerHour ?? DBNull.Value),
            new SqlParameter("@HaltingRatePerDay", (object?)request.HaltingRatePerDay ?? DBNull.Value),
            new SqlParameter("@EffectiveFrom", request.EffectiveFrom.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@EffectiveTo", request.EffectiveTo.HasValue ? request.EffectiveTo.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("billing.usp_InsertRateCard", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteRateCardAsync(int rateCardId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@RateCardId", rateCardId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("billing.usp_DeleteRateCard", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Generate invoice from shipments ----

    public async Task<IReadOnlyList<UninvoicedShipmentDto>> GetUninvoicedShipmentsAsync(int customerId, DateOnly fromDate, DateOnly toDate, CancellationToken cancellationToken = default)
    {
        var shipmentParameters = new[]
        {
            new SqlParameter("@CustomerId", customerId),
            new SqlParameter("@FromDate", fromDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@ToDate", toDate.ToDateTime(TimeOnly.MinValue))
        };
        var shipmentsTable = await _db.QueryProcedureAsync("billing.usp_GetUninvoicedShipments", shipmentParameters, cancellationToken);

        var shipments = shipmentsTable.Rows.Cast<DataRow>()
            .Select(row => new UninvoicedShipmentDto
            {
                Id = Convert.ToInt32(row["Id"]),
                TrackingNo = row["TrackingNo"] as string,
                OriginCityId = Convert.ToInt32(row["OriginCityId"]),
                OriginCityName = row["OriginCityName"].ToString() ?? string.Empty,
                DestinationCityId = Convert.ToInt32(row["DestinationCityId"]),
                DestinationCityName = row["DestinationCityName"].ToString() ?? string.Empty,
                ShipmentDate = DateOnly.FromDateTime(Convert.ToDateTime(row["ShipmentDate"])),
                TotalWeightKg = Convert.ToDecimal(row["TotalWeightKg"]),
                RouteDistanceKm = row["RouteDistanceKm"] == DBNull.Value ? null : Convert.ToDecimal(row["RouteDistanceKm"]),
                TotalPackages = row["TotalPackages"] == DBNull.Value ? null : Convert.ToInt32(row["TotalPackages"])
            })
            .ToList();

        if (shipments.Count == 0)
            return shipments;

        // One applicable-cards lookup per distinct route on this batch
        // (same customer throughout - this whole call is scoped to one
        // customer) rather than per shipment, since most uninvoiced
        // shipments for a customer share an origin/destination pair.
        var rateCardsByRoute = new Dictionary<(int Origin, int Destination), IReadOnlyList<RateCardDto>>();

        foreach (var shipment in shipments)
        {
            var routeKey = (shipment.OriginCityId, shipment.DestinationCityId);
            if (!rateCardsByRoute.TryGetValue(routeKey, out var candidates))
            {
                candidates = await GetApplicableRateCardsAsync(customerId, shipment.OriginCityId, shipment.DestinationCityId, shipment.ShipmentDate, cancellationToken);
                rateCardsByRoute[routeKey] = candidates;
            }

            var match = RateCardMatcher.SelectBestMatch(candidates);
            if (match is not null)
            {
                shipment.EstimatedAmount = FreightCalculator.CalculateFreight(
                    match.Basis, match.RatePerTrip, match.RatePerTon, match.RatePerKm, match.RatePerPackage,
                    match.MinimumChargeableWeightKg, shipment.TotalWeightKg, shipment.RouteDistanceKm, shipment.TotalPackages ?? 0);
            }
        }

        return shipments;
    }

    public async Task<IReadOnlyList<RateCardDto>> GetApplicableRateCardsAsync(int customerId, int originCityId, int destinationCityId, DateOnly asOfDate, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@CustomerId", customerId),
            new SqlParameter("@OriginCityId", originCityId),
            new SqlParameter("@DestinationCityId", destinationCityId),
            new SqlParameter("@AsOfDate", asOfDate.ToDateTime(TimeOnly.MinValue))
        };

        var table = await _db.QueryProcedureAsync("billing.usp_GetApplicableRateCards", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>().Select(MapRateCard).ToList();
    }

    // ---- Shipment charges (F4) ----

    public async Task<IReadOnlyList<ShipmentChargeDto>> GetShipmentChargesAsync(int shipmentId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@ShipmentId", shipmentId) };
        var table = await _db.QueryProcedureAsync("billing.usp_GetShipmentCharges", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new ShipmentChargeDto
            {
                Id = Convert.ToInt32(row["Id"]),
                ShipmentId = Convert.ToInt32(row["ShipmentId"]),
                ChargeType = row["ChargeType"].ToString() ?? string.Empty,
                Amount = Convert.ToDecimal(row["Amount"]),
                Description = row["Description"] as string,
                IsOverridden = Convert.ToBoolean(row["IsOverridden"]),
                OverrideReason = row["OverrideReason"] as string,
                IsInvoiced = Convert.ToBoolean(row["IsInvoiced"]),
                CreatedAt = Convert.ToDateTime(row["CreatedAt"]),
                CreatedBy = row["CreatedBy"] as string
            })
            .ToList();
    }

    public async Task<(bool Success, string? ErrorMessage, int? NewId)> CreateShipmentChargeAsync(CreateShipmentChargeRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var errorMessageParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 500) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@ShipmentId", request.ShipmentId),
            new SqlParameter("@ChargeType", request.ChargeType),
            new SqlParameter("@Amount", request.Amount),
            new SqlParameter("@Description", (object?)request.Description ?? DBNull.Value),
            new SqlParameter("@IsOverridden", request.IsOverridden),
            new SqlParameter("@OverrideReason", (object?)request.OverrideReason ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy),
            successParam,
            errorMessageParam
        };

        var table = await _db.QueryProcedureAsync("billing.usp_InsertShipmentCharge", parameters, cancellationToken);

        var success = successParam.Value is bool b && b;
        var errorMessage = errorMessageParam.Value as string;
        int? newId = success && table.Rows.Count > 0 ? Convert.ToInt32(table.Rows[0]["NewId"]) : null;

        return (success, success ? null : errorMessage, newId);
    }

    public async Task<bool> DeleteShipmentChargeAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("billing.usp_DeleteShipmentCharge", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<(bool Success, string? ErrorMessage, int? NewInvoiceId)> CreateInvoiceFromChargesAsync(GenerateInvoiceFromChargesRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var errorMessageParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 500) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@InvoiceNo", request.InvoiceNo),
            new SqlParameter("@CustomerId", request.CustomerId),
            new SqlParameter("@InvoiceDate", request.InvoiceDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@DueDate", request.DueDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@DiscountAmount", request.DiscountAmount),
            new SqlParameter("@TaxAmount", request.TaxAmount),
            new SqlParameter("@StatusId", request.StatusId),
            BuildIntListParameter("@ShipmentChargeIds", request.ShipmentChargeIds),
            new SqlParameter("@CreatedBy", createdBy),
            successParam,
            errorMessageParam
        };

        var table = await _db.QueryProcedureAsync("billing.usp_InsertInvoiceFromCharges", parameters, cancellationToken);

        var success = successParam.Value is bool b && b;
        var errorMessage = errorMessageParam.Value as string;
        int? newInvoiceId = success && table.Rows.Count > 0 ? Convert.ToInt32(table.Rows[0]["InvoiceId"]) : null;

        return (success, success ? null : errorMessage, newInvoiceId);
    }

    private static SqlParameter BuildIntListParameter(string parameterName, IEnumerable<int> ids)
    {
        var table = new DataTable();
        table.Columns.Add("Id", typeof(int));
        foreach (var id in ids)
            table.Rows.Add(id);

        return new SqlParameter(parameterName, SqlDbType.Structured)
        {
            TypeName = "auth.IntList_TVP",
            Value = table
        };
    }

    // ---- Vendors (F5) ----

    public async Task<IReadOnlyList<VendorDto>> GetVendorsAsync(bool activeOnly, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@ActiveOnly", activeOnly) };
        var table = await _db.QueryProcedureAsync("billing.usp_GetVendors", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>().Select(MapVendor).ToList();
    }

    public async Task<VendorDto?> GetVendorByIdAsync(int vendorId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@VendorId", vendorId) };
        var table = await _db.QueryProcedureAsync("billing.usp_GetVendorById", parameters, cancellationToken);

        return table.Rows.Count == 0 ? null : MapVendor(table.Rows[0]);
    }

    public async Task<int> CreateVendorAsync(CreateVendorRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@ContactName", (object?)request.ContactName ?? DBNull.Value),
            new SqlParameter("@ContactPhone", (object?)request.ContactPhone ?? DBNull.Value),
            new SqlParameter("@ContactEmail", (object?)request.ContactEmail ?? DBNull.Value),
            new SqlParameter("@Address", (object?)request.Address ?? DBNull.Value),
            new SqlParameter("@BankAccountNo", (object?)request.BankAccountNo ?? DBNull.Value),
            new SqlParameter("@BankIfscCode", (object?)request.BankIfscCode ?? DBNull.Value),
            new SqlParameter("@PanNo", (object?)request.PanNo ?? DBNull.Value),
            new SqlParameter("@GstinNo", (object?)request.GstinNo ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("billing.usp_InsertVendor", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateVendorAsync(UpdateVendorRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@VendorId", request.VendorId),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@ContactName", (object?)request.ContactName ?? DBNull.Value),
            new SqlParameter("@ContactPhone", (object?)request.ContactPhone ?? DBNull.Value),
            new SqlParameter("@ContactEmail", (object?)request.ContactEmail ?? DBNull.Value),
            new SqlParameter("@Address", (object?)request.Address ?? DBNull.Value),
            new SqlParameter("@BankAccountNo", (object?)request.BankAccountNo ?? DBNull.Value),
            new SqlParameter("@BankIfscCode", (object?)request.BankIfscCode ?? DBNull.Value),
            new SqlParameter("@PanNo", (object?)request.PanNo ?? DBNull.Value),
            new SqlParameter("@GstinNo", (object?)request.GstinNo ?? DBNull.Value),
            new SqlParameter("@IsActive", request.IsActive),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("billing.usp_UpdateVendor", parameters, cancellationToken);
        return isUpdatedParam.Value is bool b && b;
    }

    // ---- Vendor bills / payments (F5) ----

    public async Task<IReadOnlyList<VendorBillDto>> GetVendorBillsAsync(int? vendorId, int? statusId, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@VendorId", (object?)vendorId ?? DBNull.Value),
            new SqlParameter("@StatusId", (object?)statusId ?? DBNull.Value)
        };
        var table = await _db.QueryProcedureAsync("billing.usp_GetVendorBills", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>().Select(MapVendorBill).ToList();
    }

    public async Task<VendorBillDetailDto?> GetVendorBillByIdAsync(int vendorBillId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@VendorBillId", vendorBillId) };
        var dataSet = await _db.QueryProcedureMultipleAsync("billing.usp_GetVendorBillById", parameters, cancellationToken);

        if (dataSet.Tables.Count == 0 || dataSet.Tables[0].Rows.Count == 0)
            return null;

        var bill = MapVendorBill(dataSet.Tables[0].Rows[0]);
        var payments = dataSet.Tables.Count > 1
            ? dataSet.Tables[1].Rows.Cast<DataRow>().Select(row => new VendorPaymentDto
            {
                Id = Convert.ToInt32(row["Id"]),
                PaymentDate = DateOnly.FromDateTime(Convert.ToDateTime(row["PaymentDate"])),
                Amount = Convert.ToDecimal(row["Amount"]),
                Method = row["Method"].ToString() ?? string.Empty,
                ReferenceNo = row["ReferenceNo"] as string
            }).ToList()
            : new List<VendorPaymentDto>();

        return new VendorBillDetailDto
        {
            Id = bill.Id,
            VendorId = bill.VendorId,
            VendorName = bill.VendorName,
            TripId = bill.TripId,
            BillNo = bill.BillNo,
            BillDate = bill.BillDate,
            DueDate = bill.DueDate,
            Amount = bill.Amount,
            StatusId = bill.StatusId,
            StatusName = bill.StatusName,
            PaidAmount = bill.PaidAmount,
            Payments = payments
        };
    }

    public async Task<(bool Success, string? ErrorMessage, int? NewId, decimal? Amount)> CreateVendorBillAsync(CreateVendorBillRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var errorMessageParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 500) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@BillNo", request.BillNo),
            new SqlParameter("@BillDate", request.BillDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@DueDate", request.DueDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@CreatedBy", createdBy),
            successParam,
            errorMessageParam
        };

        var table = await _db.QueryProcedureAsync("billing.usp_InsertVendorBill", parameters, cancellationToken);

        var success = successParam.Value is bool b && b;
        var errorMessage = errorMessageParam.Value as string;
        int? newId = success && table.Rows.Count > 0 ? Convert.ToInt32(table.Rows[0]["NewId"]) : null;
        decimal? amount = success && table.Rows.Count > 0 ? Convert.ToDecimal(table.Rows[0]["Amount"]) : null;

        return (success, success ? null : errorMessage, newId, amount);
    }

    public async Task<int> CreateVendorPaymentAsync(CreateVendorPaymentRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@VendorBillId", request.VendorBillId),
            new SqlParameter("@PaymentDate", request.PaymentDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@Amount", request.Amount),
            new SqlParameter("@Method", request.Method),
            new SqlParameter("@ReferenceNo", (object?)request.ReferenceNo ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("billing.usp_InsertVendorPayment", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteVendorPaymentAsync(int paymentId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@PaymentId", paymentId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("billing.usp_DeleteVendorPayment", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<VendorOutstandingBalanceDto> GetVendorOutstandingBalanceAsync(int vendorId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@VendorId", vendorId) };
        var table = await _db.QueryProcedureAsync("billing.usp_GetVendorOutstandingBalance", parameters, cancellationToken);

        if (table.Rows.Count == 0)
            return new VendorOutstandingBalanceDto { VendorId = vendorId };

        var row = table.Rows[0];
        return new VendorOutstandingBalanceDto
        {
            VendorId = vendorId,
            OutstandingBalance = Convert.ToDecimal(row["OutstandingBalance"])
        };
    }

    public async Task<IReadOnlyList<VendorAgingReportLineDto>> GetVendorAgingReportAsync(DateOnly? asOfDate, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@AsOfDate", asOfDate.HasValue ? asOfDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value)
        };
        var table = await _db.QueryProcedureAsync("billing.usp_GetVendorAgingReport", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new VendorAgingReportLineDto
            {
                Id = Convert.ToInt32(row["Id"]),
                BillNo = row["BillNo"].ToString() ?? string.Empty,
                VendorId = Convert.ToInt32(row["VendorId"]),
                VendorName = row["VendorName"].ToString() ?? string.Empty,
                BillDate = DateOnly.FromDateTime(Convert.ToDateTime(row["BillDate"])),
                DueDate = DateOnly.FromDateTime(Convert.ToDateTime(row["DueDate"])),
                OutstandingAmount = Convert.ToDecimal(row["OutstandingAmount"]),
                DaysOverdue = Convert.ToInt32(row["DaysOverdue"])
            })
            .ToList();
    }

    private static VendorDto MapVendor(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        Code = row["Code"].ToString() ?? string.Empty,
        Name = row["Name"].ToString() ?? string.Empty,
        ContactName = row["ContactName"] as string,
        ContactPhone = row["ContactPhone"] as string,
        ContactEmail = row["ContactEmail"] as string,
        Address = row["Address"] as string,
        BankAccountNo = row["BankAccountNo"] as string,
        BankIfscCode = row["BankIfscCode"] as string,
        PanNo = row["PanNo"] as string,
        GstinNo = row["GstinNo"] as string,
        IsActive = Convert.ToBoolean(row["IsActive"])
    };

    private static VendorBillDto MapVendorBill(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        VendorId = Convert.ToInt32(row["VendorId"]),
        VendorName = row["VendorName"].ToString() ?? string.Empty,
        TripId = Convert.ToInt32(row["TripId"]),
        BillNo = row["BillNo"].ToString() ?? string.Empty,
        BillDate = DateOnly.FromDateTime(Convert.ToDateTime(row["BillDate"])),
        DueDate = DateOnly.FromDateTime(Convert.ToDateTime(row["DueDate"])),
        Amount = Convert.ToDecimal(row["Amount"]),
        StatusId = Convert.ToInt32(row["StatusId"]),
        StatusName = row["StatusName"].ToString() ?? string.Empty,
        PaidAmount = Convert.ToDecimal(row["PaidAmount"])
    };

    // ---- Payments ----

    public async Task<int> CreatePaymentAsync(CreatePaymentRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@PaymentDate", request.PaymentDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@Amount", request.Amount),
            new SqlParameter("@Method", request.Method),
            new SqlParameter("@InvoiceId", (object?)request.InvoiceId ?? DBNull.Value),
            new SqlParameter("@ShipmentId", (object?)request.ShipmentId ?? DBNull.Value),
            new SqlParameter("@ReferenceNo", (object?)request.ReferenceNo ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("billing.usp_InsertPayment", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeletePaymentAsync(int paymentId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@PaymentId", paymentId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("billing.usp_DeletePayment", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- AR aging ----

    public async Task<IReadOnlyList<AgingReportLineDto>> GetAgingReportAsync(DateOnly? asOfDate, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@AsOfDate", asOfDate.HasValue ? asOfDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value)
        };

        var table = await _db.QueryProcedureAsync("billing.usp_GetAgingReport", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new AgingReportLineDto
            {
                Id = Convert.ToInt32(row["Id"]),
                InvoiceNo = row["InvoiceNo"].ToString() ?? string.Empty,
                CustomerId = Convert.ToInt32(row["CustomerId"]),
                CustomerName = row["CustomerName"].ToString() ?? string.Empty,
                InvoiceDate = DateOnly.FromDateTime(Convert.ToDateTime(row["InvoiceDate"])),
                DueDate = DateOnly.FromDateTime(Convert.ToDateTime(row["DueDate"])),
                OutstandingAmount = Convert.ToDecimal(row["OutstandingAmount"]),
                DaysOverdue = Convert.ToInt32(row["DaysOverdue"])
            })
            .ToList();
    }

    private static CustomerDto MapCustomer(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        Code = row["Code"].ToString() ?? string.Empty,
        Name = row["Name"].ToString() ?? string.Empty,
        IsActive = Convert.ToBoolean(row["IsActive"]),
        CreditLimit = row["CreditLimit"] == DBNull.Value ? null : Convert.ToDecimal(row["CreditLimit"])
    };

    private static RateCardDto MapRateCard(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        CustomerId = row["CustomerId"] == DBNull.Value ? null : Convert.ToInt32(row["CustomerId"]),
        CustomerName = row["CustomerName"] as string,
        OriginCityId = row["OriginCityId"] == DBNull.Value ? null : Convert.ToInt32(row["OriginCityId"]),
        OriginCityName = row["OriginCityName"] as string,
        DestinationCityId = row["DestinationCityId"] == DBNull.Value ? null : Convert.ToInt32(row["DestinationCityId"]),
        DestinationCityName = row["DestinationCityName"] as string,
        RatePerKg = Convert.ToDecimal(row["RatePerKg"]),
        RatePerKm = Convert.ToDecimal(row["RatePerKm"]),
        Basis = row["Basis"].ToString() ?? string.Empty,
        RatePerTrip = row["RatePerTrip"] == DBNull.Value ? null : Convert.ToDecimal(row["RatePerTrip"]),
        RatePerTon = row["RatePerTon"] == DBNull.Value ? null : Convert.ToDecimal(row["RatePerTon"]),
        RatePerPackage = row["RatePerPackage"] == DBNull.Value ? null : Convert.ToDecimal(row["RatePerPackage"]),
        MinimumChargeableWeightKg = row["MinimumChargeableWeightKg"] == DBNull.Value ? null : Convert.ToDecimal(row["MinimumChargeableWeightKg"]),
        LoadingRatePerEvent = row["LoadingRatePerEvent"] == DBNull.Value ? null : Convert.ToDecimal(row["LoadingRatePerEvent"]),
        UnloadingRatePerEvent = row["UnloadingRatePerEvent"] == DBNull.Value ? null : Convert.ToDecimal(row["UnloadingRatePerEvent"]),
        DetentionFreeHours = row["DetentionFreeHours"] == DBNull.Value ? null : Convert.ToDecimal(row["DetentionFreeHours"]),
        DetentionRatePerHour = row["DetentionRatePerHour"] == DBNull.Value ? null : Convert.ToDecimal(row["DetentionRatePerHour"]),
        HaltingRatePerDay = row["HaltingRatePerDay"] == DBNull.Value ? null : Convert.ToDecimal(row["HaltingRatePerDay"]),
        EffectiveFrom = DateOnly.FromDateTime(Convert.ToDateTime(row["EffectiveFrom"])),
        EffectiveTo = row["EffectiveTo"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["EffectiveTo"]))
    };

    // ---- Claims (F7) ----

    public async Task<PagedResult<ClaimDto>> GetClaimsAsync(ClaimFilterRequest filter, int pageNumber, int pageSize, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@ShipmentId", (object?)filter.ShipmentId ?? DBNull.Value),
            new SqlParameter("@StatusId", (object?)filter.StatusId ?? DBNull.Value),
            new SqlParameter("@FromDate", filter.FromDate is null ? DBNull.Value : filter.FromDate.Value.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@ToDate", filter.ToDate is null ? DBNull.Value : filter.ToDate.Value.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@PageNumber", pageNumber),
            new SqlParameter("@PageSize", pageSize)
        };

        var table = await _db.QueryProcedureAsync("billing.usp_GetClaims", parameters, cancellationToken);

        var items = table.Rows.Cast<DataRow>().Select(MapClaim).ToList();
        var totalCount = table.Rows.Count > 0 ? Convert.ToInt32(table.Rows[0]["TotalCount"]) : 0;

        return new PagedResult<ClaimDto>
        {
            Items = items,
            TotalCount = totalCount,
            PageNumber = pageNumber,
            PageSize = pageSize
        };
    }

    public async Task<ClaimDetailDto?> GetClaimByIdAsync(int claimId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@ClaimId", claimId) };
        var dataSet = await _db.QueryProcedureMultipleAsync("billing.usp_GetClaimById", parameters, cancellationToken);

        if (dataSet.Tables.Count == 0 || dataSet.Tables[0].Rows.Count == 0)
            return null;

        var claim = MapClaim(dataSet.Tables[0].Rows[0]);

        var history = dataSet.Tables.Count > 1
            ? dataSet.Tables[1].Rows.Cast<DataRow>().Select(row => new ClaimStatusHistoryDto
            {
                Id = Convert.ToInt32(row["Id"]),
                StatusId = Convert.ToInt32(row["StatusId"]),
                StatusName = row["StatusName"].ToString() ?? string.Empty,
                ChangedAt = Convert.ToDateTime(row["ChangedAt"]),
                Notes = row["Notes"] as string
            }).ToList()
            : new List<ClaimStatusHistoryDto>();

        return new ClaimDetailDto
        {
            Id = claim.Id,
            ShipmentId = claim.ShipmentId,
            TrackingNo = claim.TrackingNo,
            ClaimantName = claim.ClaimantName,
            ClaimantPhone = claim.ClaimantPhone,
            AmountClaimed = claim.AmountClaimed,
            StatusId = claim.StatusId,
            StatusName = claim.StatusName,
            SettledAmount = claim.SettledAmount,
            SettlementMethod = claim.SettlementMethod,
            Notes = claim.Notes,
            CreatedAt = claim.CreatedAt,
            StatusHistory = history
        };
    }

    public async Task<int> CreateClaimAsync(CreateClaimRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@ShipmentId", request.ShipmentId),
            new SqlParameter("@ClaimantName", request.ClaimantName),
            new SqlParameter("@ClaimantPhone", (object?)request.ClaimantPhone ?? DBNull.Value),
            new SqlParameter("@AmountClaimed", request.AmountClaimed),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@Notes", (object?)request.Notes ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("billing.usp_InsertClaim", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<(bool Success, string? ErrorMessage)> UpdateClaimAsync(UpdateClaimRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var errorMessageParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 500) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@ClaimId", request.ClaimId),
            new SqlParameter("@ClaimantName", request.ClaimantName),
            new SqlParameter("@ClaimantPhone", (object?)request.ClaimantPhone ?? DBNull.Value),
            new SqlParameter("@AmountClaimed", request.AmountClaimed),
            new SqlParameter("@Notes", (object?)request.Notes ?? DBNull.Value),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam,
            errorMessageParam
        };

        await _db.ExecuteNonQueryProcedureAsync("billing.usp_UpdateClaim", parameters, cancellationToken);

        var success = successParam.Value is bool b && b;
        return (success, success ? null : errorMessageParam.Value as string);
    }

    public async Task<(bool Success, string? ErrorMessage)> UpdateClaimStatusAsync(UpdateClaimStatusRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var errorMessageParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 500) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@ClaimId", request.ClaimId),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@Notes", (object?)request.Notes ?? DBNull.Value),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam,
            errorMessageParam
        };

        await _db.ExecuteNonQueryProcedureAsync("billing.usp_UpdateClaimStatus", parameters, cancellationToken);

        var success = successParam.Value is bool b && b;
        return (success, success ? null : errorMessageParam.Value as string);
    }

    public async Task<(bool Success, string? ErrorMessage)> SettleClaimAsync(SettleClaimRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var errorMessageParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 500) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@ClaimId", request.ClaimId),
            new SqlParameter("@SettledAmount", request.SettledAmount),
            new SqlParameter("@SettlementMethod", request.SettlementMethod),
            new SqlParameter("@Notes", (object?)request.Notes ?? DBNull.Value),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam,
            errorMessageParam
        };

        await _db.ExecuteNonQueryProcedureAsync("billing.usp_SettleClaim", parameters, cancellationToken);

        var success = successParam.Value is bool b && b;
        return (success, success ? null : errorMessageParam.Value as string);
    }

    private static ClaimDto MapClaim(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        ShipmentId = Convert.ToInt32(row["ShipmentId"]),
        TrackingNo = row["TrackingNo"].ToString() ?? string.Empty,
        ClaimantName = row["ClaimantName"].ToString() ?? string.Empty,
        ClaimantPhone = row["ClaimantPhone"] as string,
        AmountClaimed = Convert.ToDecimal(row["AmountClaimed"]),
        StatusId = Convert.ToInt32(row["StatusId"]),
        StatusName = row["StatusName"].ToString() ?? string.Empty,
        SettledAmount = row["SettledAmount"] == DBNull.Value ? null : Convert.ToDecimal(row["SettledAmount"]),
        SettlementMethod = row["SettlementMethod"] as string,
        Notes = row["Notes"] as string,
        CreatedAt = Convert.ToDateTime(row["CreatedAt"])
    };

    private static InvoiceDto MapInvoice(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        InvoiceNo = row["InvoiceNo"].ToString() ?? string.Empty,
        CustomerId = Convert.ToInt32(row["CustomerId"]),
        CustomerName = row["CustomerName"].ToString() ?? string.Empty,
        InvoiceDate = DateOnly.FromDateTime(Convert.ToDateTime(row["InvoiceDate"])),
        DueDate = DateOnly.FromDateTime(Convert.ToDateTime(row["DueDate"])),
        Subtotal = Convert.ToDecimal(row["Subtotal"]),
        DiscountAmount = Convert.ToDecimal(row["DiscountAmount"]),
        TaxAmount = Convert.ToDecimal(row["TaxAmount"]),
        TotalAmount = Convert.ToDecimal(row["TotalAmount"]),
        StatusId = Convert.ToInt32(row["StatusId"]),
        StatusName = row["StatusName"].ToString() ?? string.Empty,
        PaidAmount = Convert.ToDecimal(row["PaidAmount"]),
        DeductionAmount = Convert.ToDecimal(row["DeductionAmount"])
    };
}
