using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;

namespace TransitCore.Api.Controllers;

[Authorize]
[Route("api/v1/[controller]")]
[ApiController]
public class OpsController : ControllerBase
{
    private readonly IOpsService _opsService;

    public OpsController(IOpsService opsService)
    {
        _opsService = opsService;
    }

    [HttpGet("routes")]
    public async Task<IActionResult> GetRoutes(CancellationToken cancellationToken)
    {
        var routes = await _opsService.GetRoutesAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<RouteDto>>.Ok(routes));
    }

    [HttpGet("trips")]
    public async Task<IActionResult> GetTrips(
        [FromQuery] TripFilterRequest filter,
        [FromQuery] int pageNumber,
        [FromQuery] int pageSize,
        CancellationToken cancellationToken)
    {
        var trips = await _opsService.GetTripsAsync(
            filter,
            pageNumber <= 0 ? 1 : pageNumber,
            pageSize <= 0 ? 25 : pageSize,
            cancellationToken);

        return Ok(ApiResponse<PagedResult<TripDto>>.Ok(trips));
    }

    [HttpGet("trips/{tripId:int}")]
    public async Task<IActionResult> GetTripById(int tripId, CancellationToken cancellationToken)
    {
        var trip = await _opsService.GetTripByIdAsync(tripId, cancellationToken);
        if (trip is null)
            return NotFound(ApiResponse<string>.Fail("Trip not found"));

        return Ok(ApiResponse<TripDetailDto>.Ok(trip));
    }

    [HttpPost("trips")]
    public async Task<IActionResult> CreateTrip([FromBody] CreateTripRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newTripId = await _opsService.CreateTripAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newTripId, "Trip created successfully"));
    }

    [HttpPut("trips/status")]
    public async Task<IActionResult> UpdateTripStatus([FromBody] UpdateTripStatusRequest request, CancellationToken cancellationToken)
    {
        var changedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        await _opsService.UpdateTripStatusAsync(request, changedBy, cancellationToken);
        return Ok(ApiResponse<string>.Ok(string.Empty, "Trip status updated successfully"));
    }

    [HttpGet("shipments")]
    public async Task<IActionResult> GetShipments([FromQuery] ShipmentFilterRequest filter, CancellationToken cancellationToken)
    {
        var shipments = await _opsService.GetShipmentsAsync(filter, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<ShipmentDto>>.Ok(shipments));
    }

    [HttpGet("shipments/{shipmentId:int}")]
    public async Task<IActionResult> GetShipmentById(int shipmentId, CancellationToken cancellationToken)
    {
        var shipment = await _opsService.GetShipmentByIdAsync(shipmentId, cancellationToken);
        if (shipment is null)
            return NotFound(ApiResponse<string>.Fail("Shipment not found"));

        return Ok(ApiResponse<ShipmentDetailDto>.Ok(shipment));
    }

    [HttpPost("shipments")]
    public async Task<IActionResult> CreateShipment([FromBody] CreateShipmentRequest request, CancellationToken cancellationToken)
    {
        if (request.Items.Count == 0)
            return BadRequest(ApiResponse<string>.Fail("At least one shipment item is required"));

        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newShipmentId = await _opsService.CreateShipmentAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newShipmentId, "Shipment created successfully"));
    }
}
