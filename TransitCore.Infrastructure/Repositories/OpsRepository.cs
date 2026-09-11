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

    public async Task<IReadOnlyList<TripDto>> GetTripsAsync(TripFilterRequest filter, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@FromDate", (object?)filter.FromDate ?? DBNull.Value),
            new SqlParameter("@ToDate", (object?)filter.ToDate ?? DBNull.Value),
            new SqlParameter("@StatusId", (object?)filter.StatusId ?? DBNull.Value),
            new SqlParameter("@VehicleId", (object?)filter.VehicleId ?? DBNull.Value),
            new SqlParameter("@DriverId", (object?)filter.DriverId ?? DBNull.Value),
            new SqlParameter("@RouteId", (object?)filter.RouteId ?? DBNull.Value)
        };

        var table = await _db.QueryProcedureAsync("ops.usp_GetTrips", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>().Select(MapTrip).ToList();
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
