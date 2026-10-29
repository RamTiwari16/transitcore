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
    public async Task<IActionResult> GetVehicles(
        [FromQuery] int? statusId,
        [FromQuery] int? vehicleTypeId,
        [FromQuery] int pageNumber,
        [FromQuery] int pageSize,
        CancellationToken cancellationToken)
    {
        var vehicles = await _fleetService.GetVehiclesAsync(
            statusId, vehicleTypeId,
            pageNumber <= 0 ? 1 : pageNumber,
            pageSize <= 0 ? 25 : pageSize,
            cancellationToken);

        return Ok(ApiResponse<PagedResult<VehicleDto>>.Ok(vehicles));
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

    [HttpGet("drivers/{driverId:int}")]
    public async Task<IActionResult> GetDriverById(int driverId, CancellationToken cancellationToken)
    {
        var driver = await _fleetService.GetDriverByIdAsync(driverId, cancellationToken);
        if (driver is null)
            return NotFound(ApiResponse<string>.Fail("Driver not found"));

        return Ok(ApiResponse<DriverDetailDto>.Ok(driver));
    }

    [HttpPost("drivers")]
    public async Task<IActionResult> CreateDriver([FromBody] CreateDriverRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newDriverId = await _fleetService.CreateDriverAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newDriverId, "Driver created successfully"));
    }

    [HttpPut("drivers")]
    public async Task<IActionResult> UpdateDriver([FromBody] UpdateDriverRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _fleetService.UpdateDriverAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Driver not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Driver updated successfully"));
    }

    [HttpGet("utilisation")]
    public async Task<IActionResult> GetFleetUtilisation([FromQuery] DateOnly fromDate, [FromQuery] DateOnly toDate, CancellationToken cancellationToken)
    {
        if (fromDate > toDate)
            return BadRequest(ApiResponse<string>.Fail("fromDate cannot be greater than toDate"));

        var utilisation = await _fleetService.GetFleetUtilisationAsync(fromDate, toDate, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<FleetUtilisationDto>>.Ok(utilisation));
    }

    // ---- Vehicle documents ----

    [HttpGet("vehicles/{vehicleId:int}/documents")]
    public async Task<IActionResult> GetVehicleDocuments(int vehicleId, CancellationToken cancellationToken)
    {
        var documents = await _fleetService.GetVehicleDocumentsAsync(vehicleId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VehicleDocumentDto>>.Ok(documents));
    }

    [HttpPost("vehicles/{vehicleId:int}/documents")]
    public async Task<IActionResult> CreateVehicleDocument(int vehicleId, [FromBody] CreateVehicleDocumentRequest request, CancellationToken cancellationToken)
    {
        // vehicleId always comes from the route, never trusted from the body,
        // so a client can't post a document against a different vehicle than
        // the URL it called.
        request.VehicleId = vehicleId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _fleetService.CreateVehicleDocumentAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Document added successfully"));
    }

    [HttpDelete("vehicle-documents/{documentId:int}")]
    public async Task<IActionResult> DeleteVehicleDocument(int documentId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _fleetService.DeleteVehicleDocumentAsync(documentId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Document not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Document removed"));
    }

    [HttpGet("vehicle-documents/expiring")]
    public async Task<IActionResult> GetExpiringVehicleDocuments([FromQuery] int daysAhead, CancellationToken cancellationToken)
    {
        var documents = await _fleetService.GetExpiringVehicleDocumentsAsync(daysAhead <= 0 ? 30 : daysAhead, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<ExpiringVehicleDocumentDto>>.Ok(documents));
    }

    // ---- Maintenance records ----

    [HttpGet("vehicles/{vehicleId:int}/maintenance")]
    public async Task<IActionResult> GetMaintenanceRecords(int vehicleId, CancellationToken cancellationToken)
    {
        var records = await _fleetService.GetMaintenanceRecordsAsync(vehicleId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<MaintenanceRecordDto>>.Ok(records));
    }

    [HttpPost("vehicles/{vehicleId:int}/maintenance")]
    public async Task<IActionResult> CreateMaintenanceRecord(int vehicleId, [FromBody] CreateMaintenanceRecordRequest request, CancellationToken cancellationToken)
    {
        request.VehicleId = vehicleId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _fleetService.CreateMaintenanceRecordAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Maintenance record added successfully"));
    }

    [HttpDelete("maintenance/{maintenanceId:int}")]
    public async Task<IActionResult> DeleteMaintenanceRecord(int maintenanceId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _fleetService.DeleteMaintenanceRecordAsync(maintenanceId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Maintenance record not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Maintenance record removed"));
    }

    // ---- Fuel logs ----

    [HttpGet("vehicles/{vehicleId:int}/fuel-logs")]
    public async Task<IActionResult> GetFuelLogs(int vehicleId, CancellationToken cancellationToken)
    {
        var logs = await _fleetService.GetFuelLogsAsync(vehicleId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<FuelLogDto>>.Ok(logs));
    }

    [HttpPost("vehicles/{vehicleId:int}/fuel-logs")]
    public async Task<IActionResult> CreateFuelLog(int vehicleId, [FromBody] CreateFuelLogRequest request, CancellationToken cancellationToken)
    {
        request.VehicleId = vehicleId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _fleetService.CreateFuelLogAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Fuel log added successfully"));
    }

    [HttpDelete("fuel-logs/{fuelLogId:int}")]
    public async Task<IActionResult> DeleteFuelLog(int fuelLogId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _fleetService.DeleteFuelLogAsync(fuelLogId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Fuel log not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Fuel log removed"));
    }

    // ---- Driver licenses ----

    [HttpGet("drivers/{driverId:int}/licenses")]
    public async Task<IActionResult> GetDriverLicenses(int driverId, CancellationToken cancellationToken)
    {
        var licenses = await _fleetService.GetDriverLicensesAsync(driverId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<DriverLicenseDto>>.Ok(licenses));
    }

    [HttpPost("drivers/{driverId:int}/licenses")]
    public async Task<IActionResult> CreateDriverLicense(int driverId, [FromBody] CreateDriverLicenseRequest request, CancellationToken cancellationToken)
    {
        request.DriverId = driverId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _fleetService.CreateDriverLicenseAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "License added successfully"));
    }

    [HttpDelete("driver-licenses/{licenseId:int}")]
    public async Task<IActionResult> DeleteDriverLicense(int licenseId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _fleetService.DeleteDriverLicenseAsync(licenseId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("License not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "License removed"));
    }

    [HttpGet("driver-licenses/expiring")]
    public async Task<IActionResult> GetExpiringDriverLicenses([FromQuery] int daysAhead, CancellationToken cancellationToken)
    {
        var licenses = await _fleetService.GetExpiringDriverLicensesAsync(daysAhead <= 0 ? 30 : daysAhead, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<ExpiringDriverLicenseDto>>.Ok(licenses));
    }

    // ---- Driver performance ----

    [HttpGet("drivers/{driverId:int}/performance")]
    public async Task<IActionResult> GetDriverPerformance(int driverId, CancellationToken cancellationToken)
    {
        var performance = await _fleetService.GetDriverPerformanceAsync(driverId, cancellationToken);
        return Ok(ApiResponse<DriverPerformanceDto>.Ok(performance));
    }

    [HttpGet("drivers/{driverId:int}/settlement")]
    public async Task<IActionResult> GetDriverSettlement(int driverId, CancellationToken cancellationToken)
    {
        var settlement = await _fleetService.GetDriverSettlementAsync(driverId, cancellationToken);
        return Ok(ApiResponse<DriverSettlementDto>.Ok(settlement));
    }
}
