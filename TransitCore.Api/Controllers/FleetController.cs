using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;

namespace TransitCore.Api.Controllers;

[Authorize]
[Route("api/v1/[controller]")]
[ApiController]
public class FleetController : ControllerBase
{
    private readonly IFleetService _fleetService;

    public FleetController(IFleetService fleetService)
    {
        _fleetService = fleetService;
    }

    [HttpGet("vehicle-types")]
    public async Task<IActionResult> GetVehicleTypes(CancellationToken cancellationToken)
    {
        var types = await _fleetService.GetVehicleTypesAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VehicleTypeDto>>.Ok(types));
    }

    [HttpGet("vehicles")]
    public async Task<IActionResult> GetVehicles([FromQuery] int? statusId, [FromQuery] int? vehicleTypeId, CancellationToken cancellationToken)
    {
        var vehicles = await _fleetService.GetVehiclesAsync(statusId, vehicleTypeId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VehicleDto>>.Ok(vehicles));
    }

    [HttpGet("vehicles/{vehicleId:int}")]
    public async Task<IActionResult> GetVehicleById(int vehicleId, CancellationToken cancellationToken)
    {
        var vehicle = await _fleetService.GetVehicleByIdAsync(vehicleId, cancellationToken);
        if (vehicle is null)
            return NotFound(ApiResponse<string>.Fail("Vehicle not found"));

        return Ok(ApiResponse<VehicleDto>.Ok(vehicle));
    }

    [HttpPost("vehicles")]
    public async Task<IActionResult> CreateVehicle([FromBody] CreateVehicleRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newVehicleId = await _fleetService.CreateVehicleAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newVehicleId, "Vehicle created successfully"));
    }

    [HttpPut("vehicles")]
    public async Task<IActionResult> UpdateVehicle([FromBody] UpdateVehicleRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _fleetService.UpdateVehicleAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Vehicle not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Vehicle updated successfully"));
    }

    [HttpGet("drivers")]
    public async Task<IActionResult> GetDrivers([FromQuery] int? statusId, CancellationToken cancellationToken)
    {
        var drivers = await _fleetService.GetDriversAsync(statusId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<DriverDto>>.Ok(drivers));
    }

    [HttpGet("utilisation")]
    public async Task<IActionResult> GetFleetUtilisation([FromQuery] DateOnly fromDate, [FromQuery] DateOnly toDate, CancellationToken cancellationToken)
    {
        if (fromDate > toDate)
            return BadRequest(ApiResponse<string>.Fail("fromDate cannot be greater than toDate"));

        var utilisation = await _fleetService.GetFleetUtilisationAsync(fromDate, toDate, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<FleetUtilisationDto>>.Ok(utilisation));
    }
}
