using System.Data;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class ReportsRepository : IReportsService
{
    private readonly SqlDataAccess _db;

    public ReportsRepository(SqlDataAccess db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<RevenueByPeriodDto>> GetRevenueByPeriodAsync(int monthsBack, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@MonthsBack", monthsBack) };
        var table = await _db.QueryProcedureAsync("billing.usp_GetRevenueByPeriod", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new RevenueByPeriodDto
            {
                PeriodLabel = row["PeriodLabel"].ToString() ?? string.Empty,
                TotalInvoiced = Convert.ToDecimal(row["TotalInvoiced"]),
                TotalCollected = Convert.ToDecimal(row["TotalCollected"])
            })
            .ToList();
    }

    public async Task<IReadOnlyList<DriverSettlementSummaryDto>> GetDriverSettlementSummaryAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("fleet.usp_GetDriverSettlementSummary", cancellationToken: cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new DriverSettlementSummaryDto
            {
                DriverId = Convert.ToInt32(row["DriverId"]),
                FullName = row["FullName"].ToString() ?? string.Empty,
                TotalAdvances = Convert.ToDecimal(row["TotalAdvances"]),
                TotalExpenses = Convert.ToDecimal(row["TotalExpenses"]),
                Balance = Convert.ToDecimal(row["Balance"])
            })
            .ToList();
    }

    public async Task<IReadOnlyList<FleetUtilisationTrendDto>> GetFleetUtilisationTrendAsync(int monthsBack, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@MonthsBack", monthsBack) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetFleetUtilisationTrend", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new FleetUtilisationTrendDto
            {
                PeriodLabel = row["PeriodLabel"].ToString() ?? string.Empty,
                UtilisationPercent = Convert.ToDecimal(row["UtilisationPercent"])
            })
            .ToList();
    }

    public async Task<IReadOnlyList<ShipmentVolumeTrendDto>> GetShipmentVolumeTrendAsync(int monthsBack, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@MonthsBack", monthsBack) };
        var table = await _db.QueryProcedureAsync("ops.usp_GetShipmentVolumeTrend", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new ShipmentVolumeTrendDto
            {
                PeriodLabel = row["PeriodLabel"].ToString() ?? string.Empty,
                ShipmentCount = Convert.ToInt32(row["ShipmentCount"])
            })
            .ToList();
    }

    public async Task<IReadOnlyList<EmptyKmReportDto>> GetEmptyKmReportAsync(DateOnly fromDate, DateOnly toDate, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@FromDate", fromDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@ToDate", toDate.ToDateTime(TimeOnly.MinValue))
        };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetEmptyKmReport", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new EmptyKmReportDto
            {
                VehicleId = Convert.ToInt32(row["VehicleId"]),
                RegistrationNo = row["RegistrationNo"].ToString() ?? string.Empty,
                TotalLoadedKm = Convert.ToDecimal(row["TotalLoadedKm"]),
                TotalEmptyKm = Convert.ToDecimal(row["TotalEmptyKm"]),
                TotalKm = Convert.ToDecimal(row["TotalKm"]),
                EmptyKmPercent = Convert.ToDecimal(row["EmptyKmPercent"]),
                TripCount = Convert.ToInt32(row["TripCount"])
            })
            .ToList();
    }

    public async Task<IReadOnlyList<VehicleAvailabilityDto>> GetVehiclesBecomingAvailableAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("fleet.usp_GetVehiclesBecomingAvailable", cancellationToken: cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new VehicleAvailabilityDto
            {
                VehicleId = Convert.ToInt32(row["VehicleId"]),
                RegistrationNo = row["RegistrationNo"].ToString() ?? string.Empty,
                VehicleTypeName = row["VehicleTypeName"].ToString() ?? string.Empty,
                IsAvailableNow = Convert.ToInt32(row["IsAvailableNow"]) == 1,
                ExpectedFreeAt = row["ExpectedFreeAt"] == DBNull.Value ? null : Convert.ToDateTime(row["ExpectedFreeAt"]),
                CurrentTripRoute = row["CurrentTripRoute"] as string
            })
            .ToList();
    }
}
