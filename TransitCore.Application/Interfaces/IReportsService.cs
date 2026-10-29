using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IReportsService
{
    Task<IReadOnlyList<RevenueByPeriodDto>> GetRevenueByPeriodAsync(int monthsBack, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<DriverSettlementSummaryDto>> GetDriverSettlementSummaryAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<FleetUtilisationTrendDto>> GetFleetUtilisationTrendAsync(int monthsBack, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ShipmentVolumeTrendDto>> GetShipmentVolumeTrendAsync(int monthsBack, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<EmptyKmReportDto>> GetEmptyKmReportAsync(DateOnly fromDate, DateOnly toDate, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<VehicleAvailabilityDto>> GetVehiclesBecomingAvailableAsync(CancellationToken cancellationToken = default);
}
