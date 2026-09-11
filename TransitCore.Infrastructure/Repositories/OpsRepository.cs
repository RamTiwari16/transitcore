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
            StatusHistory = history
        };
    }

    public async Task<int> CreateTripAsync(CreateTripRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@RouteId", request.RouteId),
            new SqlParameter("@VehicleId", request.VehicleId),
            new SqlParameter("@DriverId", request.DriverId),
            new SqlParameter("@ScheduledDeparture", request.ScheduledDeparture),
            new SqlParameter("@ScheduledArrival", request.ScheduledArrival),
            new SqlParameter("@StatusId", request.StatusId),
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
                WeightKg = row["WeightKg"] == DBNull.Value ? null : Convert.ToDecimal(row["WeightKg"])
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
            Items = items
        };
    }

    public async Task<int> CreateShipmentAsync(CreateShipmentRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var itemsTable = new DataTable();
        itemsTable.Columns.Add("Description", typeof(string));
        itemsTable.Columns.Add("Quantity", typeof(decimal));
        itemsTable.Columns.Add("UnitOfMeasureId", typeof(int));
        itemsTable.Columns.Add("WeightKg", typeof(decimal));

        foreach (var item in request.Items)
        {
            var row = itemsTable.NewRow();
            row["Description"] = item.Description;
            row["Quantity"] = item.Quantity;
            row["UnitOfMeasureId"] = item.UnitOfMeasureId;
            row["WeightKg"] = (object?)item.WeightKg ?? DBNull.Value;
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
            new SqlParameter("@TripId", (object?)request.TripId ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy),
            itemsParameter
        };

        var newId = await _db.ExecuteScalarProcedureAsync("ops.usp_InsertShipment", parameters, cancellationToken);
        return Convert.ToInt32(newId);
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
        ShipmentDate = DateOnly.FromDateTime(Convert.ToDateTime(row["ShipmentDate"]))
    };

    private static TripDto MapTrip(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        RouteId = Convert.ToInt32(row["RouteId"]),
        RouteName = row["RouteName"].ToString() ?? string.Empty,
        VehicleId = Convert.ToInt32(row["VehicleId"]),
        RegistrationNo = row["RegistrationNo"].ToString() ?? string.Empty,
        DriverId = Convert.ToInt32(row["DriverId"]),
        DriverName = row["DriverName"].ToString() ?? string.Empty,
        ScheduledDeparture = Convert.ToDateTime(row["ScheduledDeparture"]),
        ScheduledArrival = Convert.ToDateTime(row["ScheduledArrival"]),
        ActualDeparture = row["ActualDeparture"] == DBNull.Value ? null : Convert.ToDateTime(row["ActualDeparture"]),
        ActualArrival = row["ActualArrival"] == DBNull.Value ? null : Convert.ToDateTime(row["ActualArrival"]),
        StatusId = Convert.ToInt32(row["StatusId"]),
        StatusName = row["StatusName"].ToString() ?? string.Empty
    };
}
