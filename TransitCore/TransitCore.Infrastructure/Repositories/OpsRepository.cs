using System.Data;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class OpsRepository : IOpsService
{
    private readonly SqlDataAccess _db;

    public OpsRepository(SqlDataAccess db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<RouteDto>> GetRoutesAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("ops.usp_GetRoutes", cancellationToken: cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new RouteDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Name = row["Name"].ToString() ?? string.Empty,
                OriginCityId = Convert.ToInt32(row["OriginCityId"]),
                OriginCityName = row["OriginCityName"].ToString() ?? string.Empty,
                DestinationCityId = Convert.ToInt32(row["DestinationCityId"]),
                DestinationCityName = row["DestinationCityName"].ToString() ?? string.Empty,
                DistanceKm = row["DistanceKm"] == DBNull.Value ? null : Convert.ToDecimal(row["DistanceKm"])
            })
            .ToList();
    }

    public async Task<int> CreateRouteAsync(CreateRouteRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@OriginCityId", request.OriginCityId),
            new SqlParameter("@DestinationCityId", request.DestinationCityId),
            new SqlParameter("@DistanceKm", (object?)request.DistanceKm ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertRoute", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<RouteDto?> GetRouteByIdAsync(int routeId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@RouteId", routeId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetRouteById", parameters, cancellationToken);

        if (table.Rows.Count == 0) return null;

        var row = table.Rows[0];
        return new RouteDto
        {
            Id = Convert.ToInt32(row["Id"]),
            Name = row["Name"].ToString() ?? string.Empty,
            OriginCityId = Convert.ToInt32(row["OriginCityId"]),
            OriginCityName = row["OriginCityName"].ToString() ?? string.Empty,
            DestinationCityId = Convert.ToInt32(row["DestinationCityId"]),
            DestinationCityName = row["DestinationCityName"].ToString() ?? string.Empty,
            DistanceKm = row["DistanceKm"] == DBNull.Value ? null : Convert.ToDecimal(row["DistanceKm"])
        };
    }

    public async Task<bool> UpdateRouteAsync(UpdateRouteRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@RouteId", request.RouteId),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@OriginCityId", request.OriginCityId),
            new SqlParameter("@DestinationCityId", request.DestinationCityId),
            new SqlParameter("@DistanceKm", (object?)request.DistanceKm ?? DBNull.Value),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_UpdateRoute", parameters, cancellationToken);

        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<PagedResult<TripDto>> GetTripsAsync(TripFilterRequest filter, int pageNumber, int pageSize, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@FromDate", (object?)filter.FromDate ?? DBNull.Value),
            new SqlParameter("@ToDate", (object?)filter.ToDate ?? DBNull.Value),
            new SqlParameter("@StatusId", (object?)filter.StatusId ?? DBNull.Value),
            new SqlParameter("@VehicleId", (object?)filter.VehicleId ?? DBNull.Value),
            new SqlParameter("@DriverId", (object?)filter.DriverId ?? DBNull.Value),
            new SqlParameter("@RouteId", (object?)filter.RouteId ?? DBNull.Value),
            new SqlParameter("@PageNumber", pageNumber),
            new SqlParameter("@PageSize", pageSize)
        };

        var table = await _db.QueryProcedureAsync("ops.usp_GetTrips", parameters, cancellationToken);

        var items = table.Rows.Cast<DataRow>().Select(MapTrip).ToList();
        var totalCount = table.Rows.Count > 0 ? Convert.ToInt32(table.Rows[0]["TotalCount"]) : 0;

        return new PagedResult<TripDto>
        {
            Items = items,
            TotalCount = totalCount,
            PageNumber = pageNumber,
            PageSize = pageSize
        };
    }

    public async Task<TripDetailDto?> GetTripByIdAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var dataSet = await _db.QueryProcedureMultipleAsync("ops.usp_GetTripById", parameters, cancellationToken);

        if (dataSet.Tables.Count == 0 || dataSet.Tables[0].Rows.Count == 0)
            return null;

        var tripRow = dataSet.Tables[0].Rows[0];
        var trip = MapTrip(tripRow);

        var history = dataSet.Tables.Count > 1
            ? dataSet.Tables[1].Rows.Cast<DataRow>().Select(row => new TripStatusHistoryDto
            {
                Id = Convert.ToInt32(row["Id"]),
                StatusId = Convert.ToInt32(row["StatusId"]),
                StatusName = row["StatusName"].ToString() ?? string.Empty,
                ChangedAt = Convert.ToDateTime(row["ChangedAt"]),
                Notes = row["Notes"] as string
            }).ToList()
            : new List<TripStatusHistoryDto>();

        return new TripDetailDto
        {
            Id = trip.Id,
            RouteId = trip.RouteId,
            RouteName = trip.RouteName,
            VehicleId = trip.VehicleId,
            RegistrationNo = trip.RegistrationNo,
            DriverId = trip.DriverId,
            DriverName = trip.DriverName,
            ScheduledDeparture = trip.ScheduledDeparture,
            ScheduledArrival = trip.ScheduledArrival,
            ActualDeparture = trip.ActualDeparture,
            ActualArrival = trip.ActualArrival,
            StatusId = trip.StatusId,
            StatusName = trip.StatusName,
            OwnershipType = trip.OwnershipType,
            VendorId = trip.VendorId,
            VendorName = trip.VendorName,
            HiredVehicleNo = trip.HiredVehicleNo,
            HiredDriverName = trip.HiredDriverName,
            HiredDriverPhone = trip.HiredDriverPhone,
            VendorFreightAmount = trip.VendorFreightAmount,
            LoadedKm = trip.LoadedKm,
            EmptyKm = trip.EmptyKm,
            StatusHistory = history
        };
    }

    public async Task<int> CreateTripAsync(CreateTripRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@RouteId", request.RouteId),
            new SqlParameter("@ScheduledDeparture", request.ScheduledDeparture),
            new SqlParameter("@ScheduledArrival", request.ScheduledArrival),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@OwnershipType", request.OwnershipType),
            new SqlParameter("@VehicleId", (object?)request.VehicleId ?? DBNull.Value),
            new SqlParameter("@DriverId", (object?)request.DriverId ?? DBNull.Value),
            new SqlParameter("@VendorId", (object?)request.VendorId ?? DBNull.Value),
            new SqlParameter("@HiredVehicleNo", (object?)request.HiredVehicleNo ?? DBNull.Value),
            new SqlParameter("@HiredDriverName", (object?)request.HiredDriverName ?? DBNull.Value),
            new SqlParameter("@HiredDriverPhone", (object?)request.HiredDriverPhone ?? DBNull.Value),
            new SqlParameter("@VendorFreightAmount", (object?)request.VendorFreightAmount ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertTrip", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task UpdateTripStatusAsync(UpdateTripStatusRequest request, string changedBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@Notes", (object?)request.Notes ?? DBNull.Value),
            new SqlParameter("@ChangedBy", changedBy)
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_UpdateTripStatus", parameters, cancellationToken);
    }

    public async Task<bool> UpdateTripAsync(UpdateTripRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@RouteId", request.RouteId),
            new SqlParameter("@ScheduledDeparture", request.ScheduledDeparture),
            new SqlParameter("@ScheduledArrival", request.ScheduledArrival),
            new SqlParameter("@OwnershipType", request.OwnershipType),
            new SqlParameter("@VehicleId", (object?)request.VehicleId ?? DBNull.Value),
            new SqlParameter("@DriverId", (object?)request.DriverId ?? DBNull.Value),
            new SqlParameter("@VendorId", (object?)request.VendorId ?? DBNull.Value),
            new SqlParameter("@HiredVehicleNo", (object?)request.HiredVehicleNo ?? DBNull.Value),
            new SqlParameter("@HiredDriverName", (object?)request.HiredDriverName ?? DBNull.Value),
            new SqlParameter("@HiredDriverPhone", (object?)request.HiredDriverPhone ?? DBNull.Value),
            new SqlParameter("@VendorFreightAmount", (object?)request.VendorFreightAmount ?? DBNull.Value),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_UpdateTrip", parameters, cancellationToken);

        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<IReadOnlyList<ShipmentDto>> GetShipmentsAsync(ShipmentFilterRequest filter, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@CustomerId", (object?)filter.CustomerId ?? DBNull.Value),
            new SqlParameter("@StatusId", (object?)filter.StatusId ?? DBNull.Value)
        };

        var table = await _db.QueryProcedureAsync("ops.usp_GetShipments", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>().Select(MapShipment).ToList();
    }

    public async Task<ShipmentDetailDto?> GetShipmentByIdAsync(int shipmentId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@ShipmentId", shipmentId) };
        var dataSet = await _db.QueryProcedureMultipleAsync("ops.usp_GetShipmentById", parameters, cancellationToken);

        if (dataSet.Tables.Count == 0 || dataSet.Tables[0].Rows.Count == 0)
            return null;

        var shipment = MapShipment(dataSet.Tables[0].Rows[0]);

        var items = dataSet.Tables.Count > 1
            ? dataSet.Tables[1].Rows.Cast<DataRow>().Select(row => new ShipmentItemDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Description = row["Description"].ToString() ?? string.Empty,
                Quantity = Convert.ToDecimal(row["Quantity"]),
                UnitOfMeasureId = Convert.ToInt32(row["UnitOfMeasureId"]),
                UnitOfMeasureCode = row["UnitOfMeasureCode"].ToString() ?? string.Empty,
                WeightKg = row["WeightKg"] == DBNull.Value ? null : Convert.ToDecimal(row["WeightKg"]),
                VolumeCbm = row["VolumeCbm"] == DBNull.Value ? null : Convert.ToDecimal(row["VolumeCbm"])
            }).ToList()
            : new List<ShipmentItemDto>();

        return new ShipmentDetailDto
        {
            Id = shipment.Id,
            TripId = shipment.TripId,
            CustomerId = shipment.CustomerId,
            CustomerName = shipment.CustomerName,
            OriginCityId = shipment.OriginCityId,
            OriginCityName = shipment.OriginCityName,
            DestinationCityId = shipment.DestinationCityId,
            DestinationCityName = shipment.DestinationCityName,
            StatusId = shipment.StatusId,
            StatusName = shipment.StatusName,
            ShipmentDate = shipment.ShipmentDate,
            TrackingNo = shipment.TrackingNo,
            FreightPaymentTypeId = shipment.FreightPaymentTypeId,
            FreightPaymentTypeName = shipment.FreightPaymentTypeName,
            ConsignorCustomerId = shipment.ConsignorCustomerId,
            ConsignorCustomerName = shipment.ConsignorCustomerName,
            ConsignorName = shipment.ConsignorName,
            ConsignorAddress = shipment.ConsignorAddress,
            ConsignorPhone = shipment.ConsignorPhone,
            ConsigneeCustomerId = shipment.ConsigneeCustomerId,
            ConsigneeCustomerName = shipment.ConsigneeCustomerName,
            ConsigneeName = shipment.ConsigneeName,
            ConsigneeAddress = shipment.ConsigneeAddress,
            ConsigneePhone = shipment.ConsigneePhone,
            CnNumber = shipment.CnNumber,
            Items = items
        };
    }

    public async Task<int> CreateShipmentAsync(CreateShipmentRequest request, string createdBy, int branchId, string financialYearCode, CancellationToken cancellationToken = default)
    {
        var itemsTable = new DataTable();
        itemsTable.Columns.Add("Description", typeof(string));
        itemsTable.Columns.Add("Quantity", typeof(decimal));
        itemsTable.Columns.Add("UnitOfMeasureId", typeof(int));
        itemsTable.Columns.Add("WeightKg", typeof(decimal));
        itemsTable.Columns.Add("VolumeCbm", typeof(decimal));

        foreach (var item in request.Items)
        {
            var row = itemsTable.NewRow();
            row["Description"] = item.Description;
            row["Quantity"] = item.Quantity;
            row["UnitOfMeasureId"] = item.UnitOfMeasureId;
            row["WeightKg"] = (object?)item.WeightKg ?? DBNull.Value;
            row["VolumeCbm"] = (object?)item.VolumeCbm ?? DBNull.Value;
            itemsTable.Rows.Add(row);
        }

        var itemsParameter = new SqlParameter("@Items", SqlDbType.Structured)
        {
            TypeName = "ops.ShipmentItemType",
            Value = itemsTable
        };

        var parameters = new[]
        {
            new SqlParameter("@CustomerId", request.CustomerId),
            new SqlParameter("@OriginCityId", request.OriginCityId),
            new SqlParameter("@DestinationCityId", request.DestinationCityId),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@ShipmentDate", request.ShipmentDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@FreightPaymentTypeId", request.FreightPaymentTypeId),
            new SqlParameter("@BranchId", branchId),
            new SqlParameter("@FinancialYearCode", financialYearCode),
            new SqlParameter("@TripId", (object?)request.TripId ?? DBNull.Value),
            new SqlParameter("@ConsignorCustomerId", (object?)request.ConsignorCustomerId ?? DBNull.Value),
            new SqlParameter("@ConsignorName", (object?)request.ConsignorName ?? DBNull.Value),
            new SqlParameter("@ConsignorAddress", (object?)request.ConsignorAddress ?? DBNull.Value),
            new SqlParameter("@ConsignorPhone", (object?)request.ConsignorPhone ?? DBNull.Value),
            new SqlParameter("@ConsigneeCustomerId", (object?)request.ConsigneeCustomerId ?? DBNull.Value),
            new SqlParameter("@ConsigneeName", (object?)request.ConsigneeName ?? DBNull.Value),
            new SqlParameter("@ConsigneeAddress", (object?)request.ConsigneeAddress ?? DBNull.Value),
            new SqlParameter("@ConsigneePhone", (object?)request.ConsigneePhone ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy),
            itemsParameter
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertShipment", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateShipmentAsync(UpdateShipmentRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@ShipmentId", request.ShipmentId),
            new SqlParameter("@CustomerId", request.CustomerId),
            new SqlParameter("@OriginCityId", request.OriginCityId),
            new SqlParameter("@DestinationCityId", request.DestinationCityId),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@ShipmentDate", request.ShipmentDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@FreightPaymentTypeId", request.FreightPaymentTypeId),
            new SqlParameter("@ConsignorCustomerId", (object?)request.ConsignorCustomerId ?? DBNull.Value),
            new SqlParameter("@ConsignorName", (object?)request.ConsignorName ?? DBNull.Value),
            new SqlParameter("@ConsignorAddress", (object?)request.ConsignorAddress ?? DBNull.Value),
            new SqlParameter("@ConsignorPhone", (object?)request.ConsignorPhone ?? DBNull.Value),
            new SqlParameter("@ConsigneeCustomerId", (object?)request.ConsigneeCustomerId ?? DBNull.Value),
            new SqlParameter("@ConsigneeName", (object?)request.ConsigneeName ?? DBNull.Value),
            new SqlParameter("@ConsigneeAddress", (object?)request.ConsigneeAddress ?? DBNull.Value),
            new SqlParameter("@ConsigneePhone", (object?)request.ConsigneePhone ?? DBNull.Value),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_UpdateShipment", parameters, cancellationToken);

        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<ConsignmentNoteDetailDto?> GetConsignmentNoteByShipmentIdAsync(int shipmentId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@ShipmentId", shipmentId) };
        var dataSet = await _db.QueryProcedureMultipleAsync("ops.usp_GetConsignmentNoteByShipmentId", parameters, cancellationToken);

        if (dataSet.Tables.Count == 0 || dataSet.Tables[0].Rows.Count == 0)
            return null;

        var row = dataSet.Tables[0].Rows[0];
        var items = dataSet.Tables.Count > 1
            ? dataSet.Tables[1].Rows.Cast<DataRow>().Select(r => new ShipmentItemDto
            {
                Id = Convert.ToInt32(r["Id"]),
                Description = r["Description"].ToString() ?? string.Empty,
                Quantity = Convert.ToDecimal(r["Quantity"]),
                UnitOfMeasureId = Convert.ToInt32(r["UnitOfMeasureId"]),
                UnitOfMeasureCode = r["UnitOfMeasureCode"].ToString() ?? string.Empty,
                WeightKg = r["WeightKg"] == DBNull.Value ? null : Convert.ToDecimal(r["WeightKg"])
            }).ToList()
            : new List<ShipmentItemDto>();

        return new ConsignmentNoteDetailDto
        {
            Id = Convert.ToInt32(row["Id"]),
            ShipmentId = Convert.ToInt32(row["ShipmentId"]),
            CnNumber = row["CnNumber"].ToString() ?? string.Empty,
            BranchId = Convert.ToInt32(row["BranchId"]),
            BranchName = row["BranchName"].ToString() ?? string.Empty,
            CnDate = DateOnly.FromDateTime(Convert.ToDateTime(row["CnDate"])),
            Packages = row["Packages"] == DBNull.Value ? null : Convert.ToInt32(row["Packages"]),
            ActualWeightKg = row["ActualWeightKg"] == DBNull.Value ? null : Convert.ToDecimal(row["ActualWeightKg"]),
            ChargedWeightKg = row["ChargedWeightKg"] == DBNull.Value ? null : Convert.ToDecimal(row["ChargedWeightKg"]),
            DeclaredValue = row["DeclaredValue"] == DBNull.Value ? null : Convert.ToDecimal(row["DeclaredValue"]),
            FreightAmount = row["FreightAmount"] == DBNull.Value ? null : Convert.ToDecimal(row["FreightAmount"]),
            Remarks = row["Remarks"] as string,
            StatusId = Convert.ToInt32(row["StatusId"]),
            StatusName = row["StatusName"].ToString() ?? string.Empty,
            CancelReason = row["CancelReason"] as string,
            CancelledAt = row["CancelledAt"] == DBNull.Value ? null : Convert.ToDateTime(row["CancelledAt"]),
            CancelledBy = row["CancelledBy"] as string,
            EwayBillNo = row["EwayBillNo"] as string,
            EwayBillGeneratedDate = row["EwayBillGeneratedDate"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["EwayBillGeneratedDate"])),
            EwayBillValidUntil = row["EwayBillValidUntil"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["EwayBillValidUntil"])),
            TrackingNo = row["TrackingNo"] as string,
            OriginCityId = Convert.ToInt32(row["OriginCityId"]),
            OriginCityName = row["OriginCityName"].ToString() ?? string.Empty,
            DestinationCityId = Convert.ToInt32(row["DestinationCityId"]),
            DestinationCityName = row["DestinationCityName"].ToString() ?? string.Empty,
            ShipmentDate = DateOnly.FromDateTime(Convert.ToDateTime(row["ShipmentDate"])),
            FreightPaymentTypeId = Convert.ToInt32(row["FreightPaymentTypeId"]),
            FreightPaymentTypeName = row["FreightPaymentTypeName"].ToString() ?? string.Empty,
            BillingPartyCustomerId = Convert.ToInt32(row["BillingPartyCustomerId"]),
            BillingPartyName = row["BillingPartyName"].ToString() ?? string.Empty,
            ConsignorCustomerId = row["ConsignorCustomerId"] == DBNull.Value ? null : Convert.ToInt32(row["ConsignorCustomerId"]),
            ConsignorCustomerName = row["ConsignorCustomerName"] as string,
            ConsignorName = row["ConsignorName"] as string,
            ConsignorAddress = row["ConsignorAddress"] as string,
            ConsignorPhone = row["ConsignorPhone"] as string,
            ConsigneeCustomerId = row["ConsigneeCustomerId"] == DBNull.Value ? null : Convert.ToInt32(row["ConsigneeCustomerId"]),
            ConsigneeCustomerName = row["ConsigneeCustomerName"] as string,
            ConsigneeName = row["ConsigneeName"] as string,
            ConsigneeAddress = row["ConsigneeAddress"] as string,
            ConsigneePhone = row["ConsigneePhone"] as string,
            TripId = row["TripId"] == DBNull.Value ? null : Convert.ToInt32(row["TripId"]),
            VehicleId = row["VehicleId"] == DBNull.Value ? null : Convert.ToInt32(row["VehicleId"]),
            VehicleRegistrationNo = row["VehicleRegistrationNo"] as string,
            DriverId = row["DriverId"] == DBNull.Value ? null : Convert.ToInt32(row["DriverId"]),
            DriverName = row["DriverName"] as string,
            Items = items
        };
    }

    public async Task<bool> CancelConsignmentNoteAsync(CancelConsignmentNoteRequest request, string cancelledBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@ShipmentId", request.ShipmentId),
            new SqlParameter("@CancelReason", request.CancelReason),
            new SqlParameter("@CancelledBy", cancelledBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_CancelConsignmentNote", parameters, cancellationToken);

        return successParam.Value is bool b && b;
    }

    private static ShipmentDto MapShipment(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        TripId = row["TripId"] == DBNull.Value ? null : Convert.ToInt32(row["TripId"]),
        CustomerId = Convert.ToInt32(row["CustomerId"]),
        CustomerName = row["CustomerName"].ToString() ?? string.Empty,
        OriginCityId = Convert.ToInt32(row["OriginCityId"]),
        OriginCityName = row["OriginCityName"].ToString() ?? string.Empty,
        DestinationCityId = Convert.ToInt32(row["DestinationCityId"]),
        DestinationCityName = row["DestinationCityName"].ToString() ?? string.Empty,
        StatusId = Convert.ToInt32(row["StatusId"]),
        StatusName = row["StatusName"].ToString() ?? string.Empty,
        ShipmentDate = DateOnly.FromDateTime(Convert.ToDateTime(row["ShipmentDate"])),
        TrackingNo = row["TrackingNo"] as string,
        FreightPaymentTypeId = Convert.ToInt32(row["FreightPaymentTypeId"]),
        FreightPaymentTypeName = row["FreightPaymentTypeName"].ToString() ?? string.Empty,
        ConsignorCustomerId = row["ConsignorCustomerId"] == DBNull.Value ? null : Convert.ToInt32(row["ConsignorCustomerId"]),
        ConsignorCustomerName = row["ConsignorCustomerName"] as string,
        ConsignorName = row["ConsignorName"] as string,
        ConsignorAddress = row["ConsignorAddress"] as string,
        ConsignorPhone = row["ConsignorPhone"] as string,
        ConsigneeCustomerId = row["ConsigneeCustomerId"] == DBNull.Value ? null : Convert.ToInt32(row["ConsigneeCustomerId"]),
        ConsigneeCustomerName = row["ConsigneeCustomerName"] as string,
        ConsigneeName = row["ConsigneeName"] as string,
        ConsigneeAddress = row["ConsigneeAddress"] as string,
        ConsigneePhone = row["ConsigneePhone"] as string,
        CnNumber = row["CnNumber"] as string
    };

    // ---- Trip expenses ----

    public async Task<IReadOnlyList<TripExpenseDto>> GetTripExpensesAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetTripExpenses", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new TripExpenseDto
            {
                Id = Convert.ToInt32(row["Id"]),
                TripId = Convert.ToInt32(row["TripId"]),
                ExpenseType = row["ExpenseType"].ToString() ?? string.Empty,
                Amount = Convert.ToDecimal(row["Amount"]),
                ExpenseDate = DateOnly.FromDateTime(Convert.ToDateTime(row["ExpenseDate"])),
                Notes = row["Notes"] as string
            })
            .ToList();
    }

    public async Task<int> CreateTripExpenseAsync(CreateTripExpenseRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@ExpenseType", request.ExpenseType),
            new SqlParameter("@Amount", request.Amount),
            new SqlParameter("@ExpenseDate", request.ExpenseDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@Notes", (object?)request.Notes ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertTripExpense", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteTripExpenseAsync(int expenseId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@ExpenseId", expenseId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_DeleteTripExpense", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Trip advances ----

    public async Task<IReadOnlyList<TripAdvanceDto>> GetTripAdvancesAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetTripAdvances", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new TripAdvanceDto
            {
                Id = Convert.ToInt32(row["Id"]),
                TripId = Convert.ToInt32(row["TripId"]),
                Amount = Convert.ToDecimal(row["Amount"]),
                AdvanceDate = DateOnly.FromDateTime(Convert.ToDateTime(row["AdvanceDate"])),
                Notes = row["Notes"] as string
            })
            .ToList();
    }

    public async Task<int> CreateTripAdvanceAsync(CreateTripAdvanceRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@Amount", request.Amount),
            new SqlParameter("@AdvanceDate", request.AdvanceDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@Notes", (object?)request.Notes ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertTripAdvance", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteTripAdvanceAsync(int advanceId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@AdvanceId", advanceId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_DeleteTripAdvance", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<TripCostSummaryDto> GetTripCostSummaryAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetTripCostSummary", parameters, cancellationToken);

        if (table.Rows.Count == 0)
            return new TripCostSummaryDto { TripId = tripId };

        var row = table.Rows[0];
        return new TripCostSummaryDto
        {
            TripId = tripId,
            TotalExpenses = Convert.ToDecimal(row["TotalExpenses"]),
            TotalAdvances = Convert.ToDecimal(row["TotalAdvances"]),
            CustomerChargesTotal = Convert.ToDecimal(row["CustomerChargesTotal"]),
            VendorFreightAmount = row["VendorFreightAmount"] == DBNull.Value ? null : Convert.ToDecimal(row["VendorFreightAmount"])
        };
    }

    // ---- Proof of delivery ----

    public async Task<ProofOfDeliveryDto?> GetProofOfDeliveryAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var dataSet = await _db.QueryProcedureMultipleAsync("ops.usp_GetProofOfDelivery", parameters, cancellationToken);

        if (dataSet.Tables.Count == 0 || dataSet.Tables[0].Rows.Count == 0)
            return null;

        var row = dataSet.Tables[0].Rows[0];
        var photos = dataSet.Tables.Count > 1
            ? dataSet.Tables[1].Rows.Cast<DataRow>().Select(r => new ProofOfDeliveryPhotoDto
            {
                Id = Convert.ToInt32(r["Id"]),
                FilePath = r["FilePath"].ToString() ?? string.Empty
            }).ToList()
            : new List<ProofOfDeliveryPhotoDto>();

        return new ProofOfDeliveryDto
        {
            Id = Convert.ToInt32(row["Id"]),
            TripId = Convert.ToInt32(row["TripId"]),
            ReceiverName = row["ReceiverName"].ToString() ?? string.Empty,
            ReceiverPhone = row["ReceiverPhone"] as string,
            DeliveredAt = Convert.ToDateTime(row["DeliveredAt"]),
            Notes = row["Notes"] as string,
            SignatureFilePath = row["SignatureFilePath"] as string,
            Photos = photos
        };
    }

    public async Task<int> CreateProofOfDeliveryAsync(CreateProofOfDeliveryRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@ReceiverName", request.ReceiverName),
            new SqlParameter("@ReceiverPhone", (object?)request.ReceiverPhone ?? DBNull.Value),
            new SqlParameter("@DeliveredAt", request.DeliveredAt),
            new SqlParameter("@Notes", (object?)request.Notes ?? DBNull.Value),
            new SqlParameter("@SignatureFilePath", (object?)request.SignatureFilePath ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = Convert.ToInt32(await _db.ExecuteScalarProcedureAsync("ops.usp_InsertProofOfDelivery", parameters, cancellationToken));

        foreach (var photoPath in request.PhotoFilePaths)
        {
            var photoParameters = new[]
            {
                new SqlParameter("@ProofOfDeliveryId", newId),
                new SqlParameter("@FilePath", photoPath)
            };
            await _db.ExecuteScalarProcedureAsync("ops.usp_InsertProofOfDeliveryPhoto", photoParameters, cancellationToken);
        }

        return newId;
    }

    // ---- Trip documents ----

    public async Task<IReadOnlyList<TripDocumentDto>> GetTripDocumentsAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetTripDocuments", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new TripDocumentDto
            {
                Id = Convert.ToInt32(row["Id"]),
                TripId = Convert.ToInt32(row["TripId"]),
                DocumentType = row["DocumentType"].ToString() ?? string.Empty,
                FileName = row["FileName"].ToString() ?? string.Empty,
                FilePath = row["FilePath"].ToString() ?? string.Empty,
                UploadedAt = Convert.ToDateTime(row["UploadedAt"])
            })
            .ToList();
    }

    public async Task<int> CreateTripDocumentAsync(int tripId, string documentType, string fileName, string filePath, string uploadedBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TripId", tripId),
            new SqlParameter("@DocumentType", documentType),
            new SqlParameter("@FileName", fileName),
            new SqlParameter("@FilePath", filePath),
            new SqlParameter("@UploadedBy", uploadedBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertTripDocument", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteTripDocumentAsync(int documentId, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[] { new SqlParameter("@DocumentId", documentId), successParam };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_DeleteTripDocument", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Trip incidents ----

    public async Task<IReadOnlyList<TripIncidentDto>> GetTripIncidentsAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetTripIncidents", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new TripIncidentDto
            {
                Id = Convert.ToInt32(row["Id"]),
                TripId = Convert.ToInt32(row["TripId"]),
                IncidentType = row["IncidentType"].ToString() ?? string.Empty,
                Description = row["Description"].ToString() ?? string.Empty,
                ReportedAt = Convert.ToDateTime(row["ReportedAt"]),
                ReportedBy = row["ReportedBy"] as string
            })
            .ToList();
    }

    public async Task<int> CreateTripIncidentAsync(CreateTripIncidentRequest request, string reportedBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@IncidentType", request.IncidentType),
            new SqlParameter("@Description", request.Description),
            new SqlParameter("@ReportedBy", reportedBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertTripIncident", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteTripIncidentAsync(int incidentId, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[] { new SqlParameter("@IncidentId", incidentId), successParam };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_DeleteTripIncident", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Route stops (multi-stop legs) ----

    public async Task<IReadOnlyList<RouteStopDto>> GetRouteStopsAsync(int routeId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@RouteId", routeId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetRouteStops", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new RouteStopDto
            {
                Id = Convert.ToInt32(row["Id"]),
                RouteId = Convert.ToInt32(row["RouteId"]),
                CityId = Convert.ToInt32(row["CityId"]),
                CityName = row["CityName"].ToString() ?? string.Empty,
                StopOrder = Convert.ToInt32(row["StopOrder"]),
                PlannedArrival = row["PlannedArrival"] == DBNull.Value ? null : Convert.ToDateTime(row["PlannedArrival"])
            })
            .ToList();
    }

    public async Task<int> CreateRouteStopAsync(CreateRouteStopRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@RouteId", request.RouteId),
            new SqlParameter("@CityId", request.CityId),
            new SqlParameter("@StopOrder", request.StopOrder),
            new SqlParameter("@PlannedArrival", (object?)request.PlannedArrival ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertRouteStop", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteRouteStopAsync(int stopId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@StopId", stopId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_DeleteRouteStop", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Trip capacity check ----

    public async Task<TripCapacityCheckDto> GetTripCapacityCheckAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetTripCapacityCheck", parameters, cancellationToken);

        if (table.Rows.Count == 0)
            return new TripCapacityCheckDto { TripId = tripId };

        var row = table.Rows[0];
        return new TripCapacityCheckDto
        {
            TripId = tripId,
            VehicleCapacityKg = row["VehicleCapacityKg"] == DBNull.Value ? null : Convert.ToDecimal(row["VehicleCapacityKg"]),
            VehicleCapacityCbm = row["VehicleCapacityCbm"] == DBNull.Value ? null : Convert.ToDecimal(row["VehicleCapacityCbm"]),
            AssignedWeightKg = row["AssignedWeightKg"] == DBNull.Value ? null : Convert.ToDecimal(row["AssignedWeightKg"]),
            AssignedVolumeCbm = row["AssignedVolumeCbm"] == DBNull.Value ? null : Convert.ToDecimal(row["AssignedVolumeCbm"])
        };
    }

    // ---- Dispatch conflict check ----

    public async Task<IReadOnlyList<TripConflictDto>> CheckTripConflictsAsync(CheckTripConflictsRequest request, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@DriverId", (object?)request.DriverId ?? DBNull.Value),
            new SqlParameter("@VehicleId", (object?)request.VehicleId ?? DBNull.Value),
            new SqlParameter("@ScheduledDeparture", request.ScheduledDeparture),
            new SqlParameter("@ScheduledArrival", request.ScheduledArrival),
            new SqlParameter("@ExcludeTripId", (object?)request.ExcludeTripId ?? DBNull.Value)
        };

        var table = await _db.QueryProcedureAsync("ops.usp_CheckTripConflicts", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new TripConflictDto
            {
                Id = Convert.ToInt32(row["Id"]),
                RouteId = Convert.ToInt32(row["RouteId"]),
                RouteName = row["RouteName"].ToString() ?? string.Empty,
                VehicleId = row["VehicleId"] == DBNull.Value ? null : Convert.ToInt32(row["VehicleId"]),
                RegistrationNo = row["RegistrationNo"] as string,
                DriverId = row["DriverId"] == DBNull.Value ? null : Convert.ToInt32(row["DriverId"]),
                DriverName = row["DriverName"] as string,
                ScheduledDeparture = Convert.ToDateTime(row["ScheduledDeparture"]),
                ScheduledArrival = Convert.ToDateTime(row["ScheduledArrival"]),
                StatusId = Convert.ToInt32(row["StatusId"]),
                StatusName = row["StatusName"].ToString() ?? string.Empty,
                IsDriverConflict = Convert.ToBoolean(row["IsDriverConflict"]),
                IsVehicleConflict = Convert.ToBoolean(row["IsVehicleConflict"])
            })
            .ToList();
    }

    // ---- Public shipment tracking ----

    public async Task<ShipmentTrackingDto?> TrackShipmentAsync(string trackingNo, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TrackingNo", trackingNo) };
        var table = await _db.QueryProcedureAsync("ops.usp_TrackShipment", parameters, cancellationToken);

        if (table.Rows.Count == 0)
            return null;

        var row = table.Rows[0];
        return new ShipmentTrackingDto
        {
            TrackingNo = row["TrackingNo"].ToString() ?? string.Empty,
            ShipmentDate = DateOnly.FromDateTime(Convert.ToDateTime(row["ShipmentDate"])),
            OriginCityName = row["OriginCityName"].ToString() ?? string.Empty,
            DestinationCityName = row["DestinationCityName"].ToString() ?? string.Empty,
            StatusName = row["StatusName"].ToString() ?? string.Empty,
            ScheduledDeparture = row["ScheduledDeparture"] == DBNull.Value ? null : Convert.ToDateTime(row["ScheduledDeparture"]),
            ScheduledArrival = row["ScheduledArrival"] == DBNull.Value ? null : Convert.ToDateTime(row["ScheduledArrival"]),
            ActualDeparture = row["ActualDeparture"] == DBNull.Value ? null : Convert.ToDateTime(row["ActualDeparture"]),
            ActualArrival = row["ActualArrival"] == DBNull.Value ? null : Convert.ToDateTime(row["ActualArrival"]),
            TripStatusName = row["TripStatusName"] as string
        };
    }

    // ---- Trip stop shipments (load/unload events) ----

    public async Task<IReadOnlyList<TripStopShipmentDto>> GetTripStopShipmentsAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetTripStopShipments", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new TripStopShipmentDto
            {
                Id = Convert.ToInt32(row["Id"]),
                TripId = Convert.ToInt32(row["TripId"]),
                ShipmentId = Convert.ToInt32(row["ShipmentId"]),
                TrackingNo = row["TrackingNo"] as string,
                CustomerId = Convert.ToInt32(row["CustomerId"]),
                CustomerName = row["CustomerName"].ToString() ?? string.Empty,
                Action = row["Action"].ToString() ?? string.Empty,
                StopType = row["StopType"].ToString() ?? string.Empty,
                RouteStopId = row["RouteStopId"] == DBNull.Value ? null : Convert.ToInt32(row["RouteStopId"]),
                StopCityName = row["StopCityName"].ToString() ?? string.Empty,
                SortKey = Convert.ToInt32(row["SortKey"]),
                CreatedAt = Convert.ToDateTime(row["CreatedAt"]),
                CreatedBy = row["CreatedBy"] as string
            })
            .ToList();
    }

    public async Task<(bool Success, string? ErrorMessage)> CreateTripStopShipmentAsync(CreateTripStopShipmentRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var errorMessageParam = new SqlParameter("@ErrorMessage", SqlDbType.NVarChar, 500) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@ShipmentId", request.ShipmentId),
            new SqlParameter("@Action", request.Action),
            new SqlParameter("@StopType", request.StopType),
            new SqlParameter("@RouteStopId", (object?)request.RouteStopId ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy),
            successParam,
            errorMessageParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_InsertTripStopShipment", parameters, cancellationToken);

        var success = successParam.Value is bool b && b;
        var errorMessage = errorMessageParam.Value as string;
        return (success, success ? null : errorMessage);
    }

    public async Task<bool> DeleteTripStopShipmentAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_DeleteTripStopShipment", parameters, cancellationToken);

        return successParam.Value is bool b && b;
    }

    // ---- Trip stop visits (arrival/departure, for detention - F4) ----

    public async Task<IReadOnlyList<TripStopVisitDto>> GetTripStopVisitsAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetTripStopVisits", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>().Select(MapTripStopVisit).ToList();
    }

    public async Task<TripStopVisitDto> UpsertTripStopVisitAsync(UpsertTripStopVisitRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@StopType", request.StopType),
            new SqlParameter("@RouteStopId", (object?)request.RouteStopId ?? DBNull.Value),
            new SqlParameter("@ArrivedAt", (object?)request.ArrivedAt ?? DBNull.Value),
            new SqlParameter("@DepartedAt", (object?)request.DepartedAt ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_UpsertTripStopVisit", parameters, cancellationToken);

        // usp_UpsertTripStopVisit's own final SELECT isn't picked up by
        // ExecuteNonQueryProcedureAsync - re-read via the list proc instead
        // of adding a second overload just for this one caller.
        var visits = await GetTripStopVisitsAsync(request.TripId, cancellationToken);
        return visits.First(v => v.StopType == request.StopType && v.RouteStopId == request.RouteStopId);
    }

    // ---- Vendor advances / deductions (F5) ----

    public async Task<IReadOnlyList<VendorAdvanceDto>> GetVendorAdvancesAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetVendorAdvances", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new VendorAdvanceDto
            {
                Id = Convert.ToInt32(row["Id"]),
                TripId = Convert.ToInt32(row["TripId"]),
                VendorId = Convert.ToInt32(row["VendorId"]),
                Amount = Convert.ToDecimal(row["Amount"]),
                AdvanceDate = DateOnly.FromDateTime(Convert.ToDateTime(row["AdvanceDate"])),
                Remarks = row["Remarks"] as string,
                CreatedAt = Convert.ToDateTime(row["CreatedAt"]),
                CreatedBy = row["CreatedBy"] as string
            })
            .ToList();
    }

    public async Task<int> CreateVendorAdvanceAsync(CreateVendorAdvanceRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@VendorId", request.VendorId),
            new SqlParameter("@Amount", request.Amount),
            new SqlParameter("@AdvanceDate", request.AdvanceDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@Remarks", (object?)request.Remarks ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertVendorAdvance", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteVendorAdvanceAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[] { new SqlParameter("@Id", id), new SqlParameter("@ModifiedBy", modifiedBy), successParam };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_DeleteVendorAdvance", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<IReadOnlyList<VendorDeductionDto>> GetVendorDeductionsAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetVendorDeductions", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new VendorDeductionDto
            {
                Id = Convert.ToInt32(row["Id"]),
                TripId = Convert.ToInt32(row["TripId"]),
                VendorId = Convert.ToInt32(row["VendorId"]),
                Amount = Convert.ToDecimal(row["Amount"]),
                Reason = row["Reason"].ToString() ?? string.Empty,
                DeductionDate = DateOnly.FromDateTime(Convert.ToDateTime(row["DeductionDate"])),
                CreatedAt = Convert.ToDateTime(row["CreatedAt"]),
                CreatedBy = row["CreatedBy"] as string
            })
            .ToList();
    }

    public async Task<int> CreateVendorDeductionAsync(CreateVendorDeductionRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@VendorId", request.VendorId),
            new SqlParameter("@Amount", request.Amount),
            new SqlParameter("@Reason", request.Reason),
            new SqlParameter("@DeductionDate", request.DeductionDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertVendorDeduction", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteVendorDeductionAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[] { new SqlParameter("@Id", id), new SqlParameter("@ModifiedBy", modifiedBy), successParam };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_DeleteVendorDeduction", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<bool> UpdateTripKmAsync(UpdateTripKmRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@TripId", request.TripId),
            new SqlParameter("@LoadedKm", request.LoadedKm),
            new SqlParameter("@EmptyKm", request.EmptyKm),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_UpdateTripKm", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Shipment item delivery reconciliation ----

    public async Task<IReadOnlyList<ShipmentItemDeliveryLineDto>> GetShipmentItemDeliveriesAsync(int shipmentId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@ShipmentId", shipmentId) };
        var dataSet = await _db.QueryProcedureMultipleAsync("ops.usp_GetShipmentItemDeliveries", parameters, cancellationToken);

        var photosByDeliveryId = dataSet.Tables.Count > 1
            ? dataSet.Tables[1].Rows.Cast<DataRow>()
                .GroupBy(r => Convert.ToInt32(r["ShipmentItemDeliveryId"]))
                .ToDictionary(g => g.Key, g => g.Select(r => new ShipmentItemDeliveryPhotoDto
                {
                    Id = Convert.ToInt32(r["Id"]),
                    FilePath = r["FilePath"].ToString() ?? string.Empty
                }).ToList())
            : new Dictionary<int, List<ShipmentItemDeliveryPhotoDto>>();

        if (dataSet.Tables.Count == 0)
            return Array.Empty<ShipmentItemDeliveryLineDto>();

        return dataSet.Tables[0].Rows.Cast<DataRow>()
            .Select(row =>
            {
                var deliveryId = row["DeliveryId"] == DBNull.Value ? (int?)null : Convert.ToInt32(row["DeliveryId"]);
                return new ShipmentItemDeliveryLineDto
                {
                    ShipmentItemId = Convert.ToInt32(row["ShipmentItemId"]),
                    Description = row["Description"].ToString() ?? string.Empty,
                    Quantity = Convert.ToDecimal(row["Quantity"]),
                    UnitOfMeasureCode = row["UnitOfMeasureCode"].ToString() ?? string.Empty,
                    WeightKg = row["WeightKg"] == DBNull.Value ? null : Convert.ToDecimal(row["WeightKg"]),
                    VolumeCbm = row["VolumeCbm"] == DBNull.Value ? null : Convert.ToDecimal(row["VolumeCbm"]),
                    Delivery = deliveryId is null ? null : new ShipmentItemDeliveryDto
                    {
                        DeliveryId = deliveryId.Value,
                        DeliveredQty = Convert.ToDecimal(row["DeliveredQty"]),
                        ShortQty = Convert.ToDecimal(row["ShortQty"]),
                        DamagedQty = Convert.ToDecimal(row["DamagedQty"]),
                        Remarks = row["Remarks"] as string,
                        RecordedAt = Convert.ToDateTime(row["RecordedAt"]),
                        Photos = photosByDeliveryId.TryGetValue(deliveryId.Value, out var photos) ? photos : new List<ShipmentItemDeliveryPhotoDto>()
                    }
                };
            })
            .ToList();
    }

    public async Task<int> CreateShipmentItemDeliveryAsync(CreateShipmentItemDeliveryRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@ShipmentItemId", request.ShipmentItemId),
            new SqlParameter("@DeliveredQty", request.DeliveredQty),
            new SqlParameter("@ShortQty", request.ShortQty),
            new SqlParameter("@DamagedQty", request.DamagedQty),
            new SqlParameter("@Remarks", (object?)request.Remarks ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = Convert.ToInt32(await _db.ExecuteScalarProcedureAsync("ops.usp_InsertShipmentItemDelivery", parameters, cancellationToken));

        foreach (var photoPath in request.PhotoFilePaths)
        {
            var photoParameters = new[]
            {
                new SqlParameter("@ShipmentItemDeliveryId", newId),
                new SqlParameter("@FilePath", photoPath)
            };
            await _db.ExecuteScalarProcedureAsync("ops.usp_InsertShipmentItemDeliveryPhoto", photoParameters, cancellationToken);
        }

        return newId;
    }

    public async Task<bool> UpdateShipmentItemDeliveryAsync(UpdateShipmentItemDeliveryRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@DeliveryId", request.DeliveryId),
            new SqlParameter("@DeliveredQty", request.DeliveredQty),
            new SqlParameter("@ShortQty", request.ShortQty),
            new SqlParameter("@DamagedQty", request.DamagedQty),
            new SqlParameter("@Remarks", (object?)request.Remarks ?? DBNull.Value),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_UpdateShipmentItemDelivery", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<int> AddShipmentItemDeliveryPhotoAsync(int deliveryId, string filePath, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@ShipmentItemDeliveryId", deliveryId),
            new SqlParameter("@FilePath", filePath)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertShipmentItemDeliveryPhoto", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<IReadOnlyList<TripDispatchComplianceCheckDto>> CheckTripDispatchComplianceAsync(int tripId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@TripId", tripId) };
        var table = await _db.QueryProcedureAsync("ops.usp_CheckTripDispatchCompliance", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new TripDispatchComplianceCheckDto
            {
                CheckType = row["CheckType"].ToString() ?? string.Empty,
                Label = row["Label"].ToString() ?? string.Empty,
                Status = row["Status"].ToString() ?? string.Empty,
                ExpiryDate = row["ExpiryDate"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["ExpiryDate"]))
            })
            .ToList();
    }

    public async Task<bool> UpdateConsignmentNoteEwayBillAsync(UpdateConsignmentNoteEwayBillRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@ShipmentId", request.ShipmentId),
            new SqlParameter("@EwayBillNo", request.EwayBillNo),
            new SqlParameter("@EwayBillGeneratedDate", request.EwayBillGeneratedDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@EwayBillValidUntil", request.EwayBillValidUntil.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("ops.usp_UpdateConsignmentNoteEwayBill", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<IReadOnlyList<ExpiringEwayBillDto>> GetExpiringEwayBillsAsync(int daysAhead, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@DaysAhead", daysAhead) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetExpiringEwayBills", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new ExpiringEwayBillDto
            {
                ConsignmentNoteId = Convert.ToInt32(row["ConsignmentNoteId"]),
                ShipmentId = Convert.ToInt32(row["ShipmentId"]),
                CnNumber = row["CnNumber"].ToString() ?? string.Empty,
                TrackingNo = row["TrackingNo"] as string,
                EwayBillNo = row["EwayBillNo"].ToString() ?? string.Empty,
                EwayBillValidUntil = DateOnly.FromDateTime(Convert.ToDateTime(row["EwayBillValidUntil"])),
                DaysUntilExpiry = Convert.ToInt32(row["DaysUntilExpiry"])
            })
            .ToList();
    }

    private static TripStopVisitDto MapTripStopVisit(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        TripId = Convert.ToInt32(row["TripId"]),
        StopType = row["StopType"].ToString() ?? string.Empty,
        RouteStopId = row["RouteStopId"] == DBNull.Value ? null : Convert.ToInt32(row["RouteStopId"]),
        StopCityName = row["StopCityName"].ToString() ?? string.Empty,
        ArrivedAt = row["ArrivedAt"] == DBNull.Value ? null : Convert.ToDateTime(row["ArrivedAt"]),
        DepartedAt = row["DepartedAt"] == DBNull.Value ? null : Convert.ToDateTime(row["DepartedAt"]),
        DwellHours = row["DwellHours"] == DBNull.Value ? null : Convert.ToDecimal(row["DwellHours"])
    };

    private static TripDto MapTrip(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        RouteId = Convert.ToInt32(row["RouteId"]),
        RouteName = row["RouteName"].ToString() ?? string.Empty,
        VehicleId = row["VehicleId"] == DBNull.Value ? null : Convert.ToInt32(row["VehicleId"]),
        RegistrationNo = row["RegistrationNo"] as string,
        DriverId = row["DriverId"] == DBNull.Value ? null : Convert.ToInt32(row["DriverId"]),
        DriverName = row["DriverName"] as string,
        ScheduledDeparture = Convert.ToDateTime(row["ScheduledDeparture"]),
        ScheduledArrival = Convert.ToDateTime(row["ScheduledArrival"]),
        ActualDeparture = row["ActualDeparture"] == DBNull.Value ? null : Convert.ToDateTime(row["ActualDeparture"]),
        ActualArrival = row["ActualArrival"] == DBNull.Value ? null : Convert.ToDateTime(row["ActualArrival"]),
        StatusId = Convert.ToInt32(row["StatusId"]),
        StatusName = row["StatusName"].ToString() ?? string.Empty,
        OwnershipType = row["OwnershipType"].ToString() ?? string.Empty,
        VendorId = row["VendorId"] == DBNull.Value ? null : Convert.ToInt32(row["VendorId"]),
        VendorName = row["VendorName"] as string,
        HiredVehicleNo = row["HiredVehicleNo"] as string,
        HiredDriverName = row["HiredDriverName"] as string,
        HiredDriverPhone = row["HiredDriverPhone"] as string,
        VendorFreightAmount = row["VendorFreightAmount"] == DBNull.Value ? null : Convert.ToDecimal(row["VendorFreightAmount"]),
        LoadedKm = row["LoadedKm"] == DBNull.Value ? null : Convert.ToDecimal(row["LoadedKm"]),
        EmptyKm = row["EmptyKm"] == DBNull.Value ? null : Convert.ToDecimal(row["EmptyKm"])
    };
}
