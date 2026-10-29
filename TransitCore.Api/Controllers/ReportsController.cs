using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;

namespace TransitCore.Api.Controllers;

[Authorize(Roles = "Admin,Manager")]
[Route("api/v1/[controller]")]
[ApiController]
public class ReportsController : ControllerBase
{
    private readonly IReportsService _reportsService;

    public ReportsController(IReportsService reportsService)
    {
        _reportsService = reportsService;
    }

    [HttpGet("revenue-by-period")]
    public async Task<IActionResult> GetRevenueByPeriod([FromQuery] int monthsBack, CancellationToken cancellationToken)
    {
        var data = await _reportsService.GetRevenueByPeriodAsync(monthsBack <= 0 ? 12 : monthsBack, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<RevenueByPeriodDto>>.Ok(data));
    }

    [HttpGet("driver-settlement-summary")]
    public async Task<IActionResult> GetDriverSettlementSummary(CancellationToken cancellationToken)
    {
        var data = await _reportsService.GetDriverSettlementSummaryAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<DriverSettlementSummaryDto>>.Ok(data));
    }

    [HttpGet("fleet-utilisation-trend")]
    public async Task<IActionResult> GetFleetUtilisationTrend([FromQuery] int monthsBack, CancellationToken cancellationToken)
    {
        var data = await _reportsService.GetFleetUtilisationTrendAsync(monthsBack <= 0 ? 6 : monthsBack, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<FleetUtilisationTrendDto>>.Ok(data));
    }

    [HttpGet("shipment-volume-trend")]
    public async Task<IActionResult> GetShipmentVolumeTrend([FromQuery] int monthsBack, CancellationToken cancellationToken)
    {
        var data = await _reportsService.GetShipmentVolumeTrendAsync(monthsBack <= 0 ? 12 : monthsBack, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<ShipmentVolumeTrendDto>>.Ok(data));
    }

    [HttpGet("empty-km")]
    public async Task<IActionResult> GetEmptyKmReport([FromQuery] DateOnly fromDate, [FromQuery] DateOnly toDate, CancellationToken cancellationToken)
    {
        var data = await _reportsService.GetEmptyKmReportAsync(fromDate, toDate, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<EmptyKmReportDto>>.Ok(data));
    }

    [HttpGet("vehicles-becoming-available")]
    public async Task<IActionResult> GetVehiclesBecomingAvailable(CancellationToken cancellationToken)
    {
        var data = await _reportsService.GetVehiclesBecomingAvailableAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VehicleAvailabilityDto>>.Ok(data));
    }
}
