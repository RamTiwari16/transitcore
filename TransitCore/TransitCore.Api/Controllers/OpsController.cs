using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Application.Services;

namespace TransitCore.Api.Controllers;

[Authorize]
[Route("api/v1/[controller]")]
[ApiController]
public class OpsController : ControllerBase
{
    private readonly IOpsService _opsService;
    private readonly IFileStorageService _fileStorage;
    private readonly IUserManagementService _userManagementService;
    private readonly IConsignmentNotePdfGenerator _consignmentNotePdfGenerator;

    public OpsController(
        IOpsService opsService,
        IFileStorageService fileStorage,
        IUserManagementService userManagementService,
        IConsignmentNotePdfGenerator consignmentNotePdfGenerator)
    {
        _opsService = opsService;
        _fileStorage = fileStorage;
        _userManagementService = userManagementService;
        _consignmentNotePdfGenerator = consignmentNotePdfGenerator;
    }

    [HttpGet("routes")]
    public async Task<IActionResult> GetRoutes(CancellationToken cancellationToken)
    {
        var routes = await _opsService.GetRoutesAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<RouteDto>>.Ok(routes));
    }

    [HttpGet("routes/{routeId:int}")]
    public async Task<IActionResult> GetRouteById(int routeId, CancellationToken cancellationToken)
    {
        var route = await _opsService.GetRouteByIdAsync(routeId, cancellationToken);
        if (route is null)
            return NotFound(ApiResponse<string>.Fail("Route not found"));

        return Ok(ApiResponse<RouteDto>.Ok(route));
    }

    [HttpPost("routes")]
    public async Task<IActionResult> CreateRoute([FromBody] CreateRouteRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newRouteId = await _opsService.CreateRouteAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newRouteId, "Route created successfully"));
    }

    [HttpPut("routes")]
    public async Task<IActionResult> UpdateRoute([FromBody] UpdateRouteRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _opsService.UpdateRouteAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Route not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Route updated successfully"));
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
        var ownershipError = ValidateOwnership(request.OwnershipType, request.VehicleId, request.DriverId, request.VendorId, request.HiredVehicleNo);
        if (ownershipError is not null)
            return BadRequest(ApiResponse<string>.Fail(ownershipError));

        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newTripId = await _opsService.CreateTripAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newTripId, "Trip created successfully"));
    }

    // Own requires a fleet vehicle+driver, and none of the hired-truck
    // fields; Hired requires a vendor+vehicle number (hired trucks aren't
    // in our fleet, so no VehicleId/DriverId), and no fleet vehicle/driver.
    // Mirrors CK_Trips_OwnershipConsistency exactly, checked here first for
    // a clean 400 instead of a raw constraint-violation 500.
    private static string? ValidateOwnership(string ownershipType, int? vehicleId, int? driverId, int? vendorId, string? hiredVehicleNo) => ownershipType switch
    {
        "Own" when vehicleId is null || driverId is null => "An Own trip requires both a vehicle and a driver",
        "Own" when vendorId is not null || hiredVehicleNo is not null => "An Own trip cannot have vendor/hired-truck details",
        "Hired" when vendorId is null || hiredVehicleNo is null => "A Hired trip requires a vendor and a hired vehicle number",
        "Hired" when vehicleId is not null || driverId is not null => "A Hired trip cannot reference a fleet vehicle or driver",
        "Own" or "Hired" => null,
        _ => "OwnershipType must be 'Own' or 'Hired'"
    };

    [HttpPut("trips/status")]
    public async Task<IActionResult> UpdateTripStatus([FromBody] UpdateTripStatusRequest request, CancellationToken cancellationToken)
    {
        var changedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        await _opsService.UpdateTripStatusAsync(request, changedBy, cancellationToken);
        return Ok(ApiResponse<string>.Ok(string.Empty, "Trip status updated successfully"));
    }

    [HttpPut("trips")]
    public async Task<IActionResult> UpdateTrip([FromBody] UpdateTripRequest request, CancellationToken cancellationToken)
    {
        var ownershipError = ValidateOwnership(request.OwnershipType, request.VehicleId, request.DriverId, request.VendorId, request.HiredVehicleNo);
        if (ownershipError is not null)
            return BadRequest(ApiResponse<string>.Fail(ownershipError));

        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _opsService.UpdateTripAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Trip not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Trip updated successfully"));
    }

    [HttpPost("trips/check-conflicts")]
    public async Task<IActionResult> CheckTripConflicts([FromBody] CheckTripConflictsRequest request, CancellationToken cancellationToken)
    {
        var conflicts = await _opsService.CheckTripConflictsAsync(request, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<TripConflictDto>>.Ok(conflicts));
    }

    [HttpGet("trips/{tripId:int}/dispatch-compliance")]
    public async Task<IActionResult> CheckTripDispatchCompliance(int tripId, CancellationToken cancellationToken)
    {
        var checks = await _opsService.CheckTripDispatchComplianceAsync(tripId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<TripDispatchComplianceCheckDto>>.Ok(checks));
    }

    [HttpGet("trips/{tripId:int}/capacity-check")]
    public async Task<IActionResult> GetTripCapacityCheck(int tripId, CancellationToken cancellationToken)
    {
        var check = await _opsService.GetTripCapacityCheckAsync(tripId, cancellationToken);
        return Ok(ApiResponse<TripCapacityCheckDto>.Ok(check));
    }

    // ---- Trip stop shipments (load/unload events) ----

    [HttpGet("trips/{tripId:int}/stop-shipments")]
    public async Task<IActionResult> GetTripStopShipments(int tripId, CancellationToken cancellationToken)
    {
        var events = await _opsService.GetTripStopShipmentsAsync(tripId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<TripStopShipmentDto>>.Ok(events));
    }

    [HttpPost("trips/{tripId:int}/stop-shipments")]
    public async Task<IActionResult> CreateTripStopShipment(int tripId, [FromBody] CreateTripStopShipmentRequest request, CancellationToken cancellationToken)
    {
        request.TripId = tripId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var (success, errorMessage) = await _opsService.CreateTripStopShipmentAsync(request, createdBy, cancellationToken);

        if (!success)
            return BadRequest(ApiResponse<string>.Fail(errorMessage ?? "Could not record this load/unload event"));

        return Ok(ApiResponse<string>.Ok(string.Empty, $"{request.Action} recorded successfully"));
    }

    [HttpDelete("trip-stop-shipments/{id:int}")]
    public async Task<IActionResult> DeleteTripStopShipment(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _opsService.DeleteTripStopShipmentAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Event not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Event removed"));
    }

    // ---- Trip stop visits (arrival/departure, for detention - F4) ----

    [HttpGet("trips/{tripId:int}/stop-visits")]
    public async Task<IActionResult> GetTripStopVisits(int tripId, CancellationToken cancellationToken)
    {
        var visits = await _opsService.GetTripStopVisitsAsync(tripId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<TripStopVisitDto>>.Ok(visits));
    }

    [HttpPost("trips/{tripId:int}/stop-visits")]
    public async Task<IActionResult> UpsertTripStopVisit(int tripId, [FromBody] UpsertTripStopVisitRequest request, CancellationToken cancellationToken)
    {
        request.TripId = tripId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var visit = await _opsService.UpsertTripStopVisitAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<TripStopVisitDto>.Ok(visit, "Visit recorded successfully"));
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

        // JwtBearer maps the token's "sub" claim to NameIdentifier on the way in.
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!int.TryParse(userIdClaim, out var userId))
            return BadRequest(ApiResponse<string>.Fail("Could not identify the current user"));

        var branchId = await _userManagementService.GetPrimaryBranchIdAsync(userId, cancellationToken);
        if (branchId is null)
            return BadRequest(ApiResponse<string>.Fail("Your account has no primary branch configured. Contact an administrator."));

        var financialYearCode = FinancialYearCalculator.GetCode(request.ShipmentDate);

        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newShipmentId = await _opsService.CreateShipmentAsync(request, createdBy, branchId.Value, financialYearCode, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newShipmentId, "Shipment created successfully"));
    }

    [HttpPut("shipments")]
    public async Task<IActionResult> UpdateShipment([FromBody] UpdateShipmentRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _opsService.UpdateShipmentAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Shipment not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Shipment updated successfully"));
    }

    // ---- Consignment notes ----

    [HttpGet("shipments/{shipmentId:int}/consignment-note")]
    public async Task<IActionResult> GetConsignmentNote(int shipmentId, CancellationToken cancellationToken)
    {
        var cn = await _opsService.GetConsignmentNoteByShipmentIdAsync(shipmentId, cancellationToken);
        if (cn is null)
            return NotFound(ApiResponse<string>.Fail("Consignment note not found"));

        return Ok(ApiResponse<ConsignmentNoteDetailDto>.Ok(cn));
    }

    [HttpGet("shipments/{shipmentId:int}/consignment-note/pdf")]
    public async Task<IActionResult> GetConsignmentNotePdf(int shipmentId, CancellationToken cancellationToken)
    {
        var cn = await _opsService.GetConsignmentNoteByShipmentIdAsync(shipmentId, cancellationToken);
        if (cn is null)
            return NotFound(ApiResponse<string>.Fail("Consignment note not found"));

        var pdfBytes = _consignmentNotePdfGenerator.Generate(cn);
        return File(pdfBytes, "application/pdf", $"{cn.CnNumber.Replace('/', '-')}.pdf");
    }

    [HttpPost("shipments/{shipmentId:int}/consignment-note/cancel")]
    public async Task<IActionResult> CancelConsignmentNote(int shipmentId, [FromBody] CancelConsignmentNoteRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.CancelReason))
            return BadRequest(ApiResponse<string>.Fail("A cancellation reason is required"));

        request.ShipmentId = shipmentId;
        var cancelledBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var cancelled = await _opsService.CancelConsignmentNoteAsync(request, cancelledBy, cancellationToken);

        if (!cancelled)
            return NotFound(ApiResponse<string>.Fail("Consignment note not found, or already cancelled"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Consignment note cancelled"));
    }

    [HttpPut("shipments/{shipmentId:int}/consignment-note/eway-bill")]
    public async Task<IActionResult> UpdateConsignmentNoteEwayBill(int shipmentId, [FromBody] UpdateConsignmentNoteEwayBillRequest request, CancellationToken cancellationToken)
    {
        request.ShipmentId = shipmentId;
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _opsService.UpdateConsignmentNoteEwayBillAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Consignment note not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "E-way bill details updated"));
    }

    [HttpGet("consignment-notes/expiring-eway-bills")]
    public async Task<IActionResult> GetExpiringEwayBills([FromQuery] int daysAhead, CancellationToken cancellationToken)
    {
        var bills = await _opsService.GetExpiringEwayBillsAsync(daysAhead <= 0 ? 3 : daysAhead, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<ExpiringEwayBillDto>>.Ok(bills));
    }

    // ---- Trip expenses ----

    [HttpGet("trips/{tripId:int}/expenses")]
    public async Task<IActionResult> GetTripExpenses(int tripId, CancellationToken cancellationToken)
    {
        var expenses = await _opsService.GetTripExpensesAsync(tripId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<TripExpenseDto>>.Ok(expenses));
    }

    [HttpPost("trips/{tripId:int}/expenses")]
    public async Task<IActionResult> CreateTripExpense(int tripId, [FromBody] CreateTripExpenseRequest request, CancellationToken cancellationToken)
    {
        request.TripId = tripId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _opsService.CreateTripExpenseAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Expense added successfully"));
    }

    [HttpDelete("trip-expenses/{expenseId:int}")]
    public async Task<IActionResult> DeleteTripExpense(int expenseId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _opsService.DeleteTripExpenseAsync(expenseId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Expense not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Expense removed"));
    }

    // ---- Trip advances ----

    [HttpGet("trips/{tripId:int}/advances")]
    public async Task<IActionResult> GetTripAdvances(int tripId, CancellationToken cancellationToken)
    {
        var advances = await _opsService.GetTripAdvancesAsync(tripId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<TripAdvanceDto>>.Ok(advances));
    }

    [HttpPost("trips/{tripId:int}/advances")]
    public async Task<IActionResult> CreateTripAdvance(int tripId, [FromBody] CreateTripAdvanceRequest request, CancellationToken cancellationToken)
    {
        request.TripId = tripId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _opsService.CreateTripAdvanceAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Advance recorded successfully"));
    }

    [HttpDelete("trip-advances/{advanceId:int}")]
    public async Task<IActionResult> DeleteTripAdvance(int advanceId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _opsService.DeleteTripAdvanceAsync(advanceId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Advance not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Advance removed"));
    }

    [HttpGet("trips/{tripId:int}/cost-summary")]
    public async Task<IActionResult> GetTripCostSummary(int tripId, CancellationToken cancellationToken)
    {
        var summary = await _opsService.GetTripCostSummaryAsync(tripId, cancellationToken);
        return Ok(ApiResponse<TripCostSummaryDto>.Ok(summary));
    }

    // ---- Vendor advances / deductions (F5) ----

    [HttpGet("trips/{tripId:int}/vendor-advances")]
    public async Task<IActionResult> GetVendorAdvances(int tripId, CancellationToken cancellationToken)
    {
        var advances = await _opsService.GetVendorAdvancesAsync(tripId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VendorAdvanceDto>>.Ok(advances));
    }

    [HttpPost("trips/{tripId:int}/vendor-advances")]
    public async Task<IActionResult> CreateVendorAdvance(int tripId, [FromBody] CreateVendorAdvanceRequest request, CancellationToken cancellationToken)
    {
        request.TripId = tripId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _opsService.CreateVendorAdvanceAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Advance recorded successfully"));
    }

    [HttpDelete("vendor-advances/{id:int}")]
    public async Task<IActionResult> DeleteVendorAdvance(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _opsService.DeleteVendorAdvanceAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Advance not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Advance removed"));
    }

    [HttpGet("trips/{tripId:int}/vendor-deductions")]
    public async Task<IActionResult> GetVendorDeductions(int tripId, CancellationToken cancellationToken)
    {
        var deductions = await _opsService.GetVendorDeductionsAsync(tripId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VendorDeductionDto>>.Ok(deductions));
    }

    [HttpPost("trips/{tripId:int}/vendor-deductions")]
    public async Task<IActionResult> CreateVendorDeduction(int tripId, [FromBody] CreateVendorDeductionRequest request, CancellationToken cancellationToken)
    {
        request.TripId = tripId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _opsService.CreateVendorDeductionAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Deduction recorded successfully"));
    }

    [HttpDelete("vendor-deductions/{id:int}")]
    public async Task<IActionResult> DeleteVendorDeduction(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _opsService.DeleteVendorDeductionAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Deduction not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Deduction removed"));
    }

    // ---- Trip loaded/empty km ----

    [HttpPut("trips/{tripId:int}/km")]
    public async Task<IActionResult> UpdateTripKm(int tripId, [FromBody] UpdateTripKmRequest request, CancellationToken cancellationToken)
    {
        request.TripId = tripId;
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _opsService.UpdateTripKmAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Trip not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Trip km updated"));
    }

    // ---- Shipment item delivery reconciliation ----

    [HttpGet("shipments/{shipmentId:int}/item-deliveries")]
    public async Task<IActionResult> GetShipmentItemDeliveries(int shipmentId, CancellationToken cancellationToken)
    {
        var lines = await _opsService.GetShipmentItemDeliveriesAsync(shipmentId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<ShipmentItemDeliveryLineDto>>.Ok(lines));
    }

    [HttpPost("shipment-items/{shipmentItemId:int}/delivery")]
    [RequestSizeLimit(20_000_000)]
    public async Task<IActionResult> CreateShipmentItemDelivery(
        int shipmentItemId,
        [FromForm] decimal deliveredQty,
        [FromForm] decimal shortQty,
        [FromForm] decimal damagedQty,
        [FromForm] string? remarks,
        [FromForm] List<IFormFile>? photos,
        CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";

        var photoPaths = new List<string>();
        foreach (var photo in photos ?? Enumerable.Empty<IFormFile>())
        {
            if (photo.Length == 0) continue;
            await using var stream = photo.OpenReadStream();
            photoPaths.Add(await _fileStorage.SaveFileAsync(stream, photo.FileName, "delivery-photos", cancellationToken));
        }

        var request = new CreateShipmentItemDeliveryRequest
        {
            ShipmentItemId = shipmentItemId,
            DeliveredQty = deliveredQty,
            ShortQty = shortQty,
            DamagedQty = damagedQty,
            Remarks = remarks,
            PhotoFilePaths = photoPaths
        };

        var newId = await _opsService.CreateShipmentItemDeliveryAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Delivery recorded"));
    }

    [HttpPut("shipment-item-deliveries/{deliveryId:int}")]
    public async Task<IActionResult> UpdateShipmentItemDelivery(int deliveryId, [FromBody] UpdateShipmentItemDeliveryRequest request, CancellationToken cancellationToken)
    {
        request.DeliveryId = deliveryId;
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _opsService.UpdateShipmentItemDeliveryAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Delivery record not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Delivery record updated"));
    }

    [HttpPost("shipment-item-deliveries/{deliveryId:int}/photos")]
    [RequestSizeLimit(20_000_000)]
    public async Task<IActionResult> AddShipmentItemDeliveryPhoto(int deliveryId, [FromForm] IFormFile photo, CancellationToken cancellationToken)
    {
        await using var stream = photo.OpenReadStream();
        var filePath = await _fileStorage.SaveFileAsync(stream, photo.FileName, "delivery-photos", cancellationToken);

        var newId = await _opsService.AddShipmentItemDeliveryPhotoAsync(deliveryId, filePath, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Photo added"));
    }

    // ---- Proof of delivery ----

    [HttpGet("trips/{tripId:int}/proof-of-delivery")]
    public async Task<IActionResult> GetProofOfDelivery(int tripId, CancellationToken cancellationToken)
    {
        // Not-yet-delivered is a normal point in a trip's life, not an error
        // condition - 200 with a null payload (the frontend shows the
        // "record delivery" form for that case) instead of 404, so opening
        // this tab on any in-progress trip doesn't trip the global
        // error-toast interceptor.
        var pod = await _opsService.GetProofOfDeliveryAsync(tripId, cancellationToken);
        return Ok(ApiResponse<ProofOfDeliveryDto?>.Ok(pod));
    }

    [HttpPost("trips/{tripId:int}/proof-of-delivery")]
    [RequestSizeLimit(20_000_000)]
    public async Task<IActionResult> CreateProofOfDelivery(
        int tripId,
        [FromForm] string receiverName,
        [FromForm] string? receiverPhone,
        [FromForm] DateTime deliveredAt,
        [FromForm] string? notes,
        [FromForm] IFormFile? signature,
        [FromForm] List<IFormFile>? photos,
        CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";

        string? signaturePath = null;
        if (signature is { Length: > 0 })
        {
            await using var stream = signature.OpenReadStream();
            signaturePath = await _fileStorage.SaveFileAsync(stream, signature.FileName, "pod-signatures", cancellationToken);
        }

        var photoPaths = new List<string>();
        foreach (var photo in photos ?? Enumerable.Empty<IFormFile>())
        {
            if (photo.Length == 0) continue;
            await using var stream = photo.OpenReadStream();
            photoPaths.Add(await _fileStorage.SaveFileAsync(stream, photo.FileName, "pod-photos", cancellationToken));
        }

        var request = new CreateProofOfDeliveryRequest
        {
            TripId = tripId,
            ReceiverName = receiverName,
            ReceiverPhone = receiverPhone,
            DeliveredAt = deliveredAt,
            Notes = notes,
            SignatureFilePath = signaturePath,
            PhotoFilePaths = photoPaths
        };

        var newId = await _opsService.CreateProofOfDeliveryAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Proof of delivery recorded"));
    }

    // ---- Trip documents ----

    [HttpGet("trips/{tripId:int}/documents")]
    public async Task<IActionResult> GetTripDocuments(int tripId, CancellationToken cancellationToken)
    {
        var documents = await _opsService.GetTripDocumentsAsync(tripId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<TripDocumentDto>>.Ok(documents));
    }

    [HttpPost("trips/{tripId:int}/documents")]
    [RequestSizeLimit(20_000_000)]
    public async Task<IActionResult> CreateTripDocument(int tripId, [FromForm] string documentType, [FromForm] IFormFile file, CancellationToken cancellationToken)
    {
        var uploadedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";

        await using var stream = file.OpenReadStream();
        var filePath = await _fileStorage.SaveFileAsync(stream, file.FileName, "trip-documents", cancellationToken);

        var newId = await _opsService.CreateTripDocumentAsync(tripId, documentType, file.FileName, filePath, uploadedBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Document uploaded successfully"));
    }

    [HttpDelete("trip-documents/{documentId:int}")]
    public async Task<IActionResult> DeleteTripDocument(int documentId, CancellationToken cancellationToken)
    {
        var deleted = await _opsService.DeleteTripDocumentAsync(documentId, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Document not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Document removed"));
    }

    // ---- Trip incidents ----

    [HttpGet("trips/{tripId:int}/incidents")]
    public async Task<IActionResult> GetTripIncidents(int tripId, CancellationToken cancellationToken)
    {
        var incidents = await _opsService.GetTripIncidentsAsync(tripId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<TripIncidentDto>>.Ok(incidents));
    }

    [HttpPost("trips/{tripId:int}/incidents")]
    public async Task<IActionResult> CreateTripIncident(int tripId, [FromBody] CreateTripIncidentRequest request, CancellationToken cancellationToken)
    {
        request.TripId = tripId;
        var reportedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _opsService.CreateTripIncidentAsync(request, reportedBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Incident reported"));
    }

    [HttpDelete("trip-incidents/{incidentId:int}")]
    public async Task<IActionResult> DeleteTripIncident(int incidentId, CancellationToken cancellationToken)
    {
        var deleted = await _opsService.DeleteTripIncidentAsync(incidentId, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Incident not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Incident removed"));
    }

    // ---- Route stops (multi-stop legs) ----

    [HttpGet("routes/{routeId:int}/stops")]
    public async Task<IActionResult> GetRouteStops(int routeId, CancellationToken cancellationToken)
    {
        var stops = await _opsService.GetRouteStopsAsync(routeId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<RouteStopDto>>.Ok(stops));
    }

    [HttpPost("routes/{routeId:int}/stops")]
    public async Task<IActionResult> CreateRouteStop(int routeId, [FromBody] CreateRouteStopRequest request, CancellationToken cancellationToken)
    {
        request.RouteId = routeId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _opsService.CreateRouteStopAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Stop added successfully"));
    }

    [HttpDelete("route-stops/{stopId:int}")]
    public async Task<IActionResult> DeleteRouteStop(int stopId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _opsService.DeleteRouteStopAsync(stopId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Stop not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Stop removed"));
    }
}
