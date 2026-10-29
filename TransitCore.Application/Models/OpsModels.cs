namespace TransitCore.Application.Models;

public class RouteDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int OriginCityId { get; set; }
    public string OriginCityName { get; set; } = string.Empty;
    public int DestinationCityId { get; set; }
    public string DestinationCityName { get; set; } = string.Empty;
    public decimal? DistanceKm { get; set; }
}

public class CreateRouteRequest
{
    public string Name { get; set; } = string.Empty;
    public int OriginCityId { get; set; }
    public int DestinationCityId { get; set; }
    public decimal? DistanceKm { get; set; }
}

public class UpdateRouteRequest
{
    public int RouteId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int OriginCityId { get; set; }
    public int DestinationCityId { get; set; }
    public decimal? DistanceKm { get; set; }
}

public class TripFilterRequest
{
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
    public int? StatusId { get; set; }
    public int? VehicleId { get; set; }
    public int? DriverId { get; set; }
    public int? RouteId { get; set; }
}

public class TripDto
{
    public int Id { get; set; }
    public int RouteId { get; set; }
    public string RouteName { get; set; } = string.Empty;
    // Own trips only - null for a Hired trip (see OwnershipType/HiredVehicleNo).
    public int? VehicleId { get; set; }
    public string? RegistrationNo { get; set; }
    public int? DriverId { get; set; }
    public string? DriverName { get; set; }
    public DateTime ScheduledDeparture { get; set; }
    public DateTime ScheduledArrival { get; set; }
    public DateTime? ActualDeparture { get; set; }
    public DateTime? ActualArrival { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public string OwnershipType { get; set; } = string.Empty;
    public int? VendorId { get; set; }
    public string? VendorName { get; set; }
    public string? HiredVehicleNo { get; set; }
    public string? HiredDriverName { get; set; }
    public string? HiredDriverPhone { get; set; }
    public decimal? VendorFreightAmount { get; set; }
    public decimal? LoadedKm { get; set; }
    public decimal? EmptyKm { get; set; }
}

public class TripStatusHistoryDto
{
    public int Id { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public DateTime ChangedAt { get; set; }
    public string? Notes { get; set; }
}

public class TripDetailDto : TripDto
{
    public IReadOnlyList<TripStatusHistoryDto> StatusHistory { get; set; } = Array.Empty<TripStatusHistoryDto>();
}

public class CreateTripRequest
{
    public int RouteId { get; set; }
    public DateTime ScheduledDeparture { get; set; }
    public DateTime ScheduledArrival { get; set; }
    public int StatusId { get; set; }
    public string OwnershipType { get; set; } = "Own";
    public int? VehicleId { get; set; }
    public int? DriverId { get; set; }
    public int? VendorId { get; set; }
    public string? HiredVehicleNo { get; set; }
    public string? HiredDriverName { get; set; }
    public string? HiredDriverPhone { get; set; }
    public decimal? VendorFreightAmount { get; set; }
}

public class UpdateTripStatusRequest
{
    public int TripId { get; set; }
    public int StatusId { get; set; }
    public string? Notes { get; set; }
}

// Header fields only (route/vehicle/driver/schedule) - status transitions go
// through UpdateTripStatusRequest instead, which is audited via
// TripStatusHistory; this proc deliberately doesn't touch StatusId.
public class UpdateTripRequest
{
    public int TripId { get; set; }
    public int RouteId { get; set; }
    public DateTime ScheduledDeparture { get; set; }
    public DateTime ScheduledArrival { get; set; }
    public string OwnershipType { get; set; } = "Own";
    public int? VehicleId { get; set; }
    public int? DriverId { get; set; }
    public int? VendorId { get; set; }
    public string? HiredVehicleNo { get; set; }
    public string? HiredDriverName { get; set; }
    public string? HiredDriverPhone { get; set; }
    public decimal? VendorFreightAmount { get; set; }
}

// Deliberately separate from UpdateTripRequest - actual run km is
// dispatch-workflow data entered once a trip is done, not part of the
// general edit form (same reasoning as ActualDeparture/ActualArrival).
public class UpdateTripKmRequest
{
    public int TripId { get; set; }
    public decimal LoadedKm { get; set; }
    public decimal EmptyKm { get; set; }
}

public class ShipmentFilterRequest
{
    public int? CustomerId { get; set; }
    public int? StatusId { get; set; }
}

public class ShipmentDto
{
    public int Id { get; set; }
    public int? TripId { get; set; }
    // BillingParty - who the shipment is invoiced to. Unchanged column/name
    // (CustomerId) from before the F1 consignor/consignee split, so every
    // existing reader of this field keeps working unmodified.
    public int CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public int OriginCityId { get; set; }
    public string OriginCityName { get; set; } = string.Empty;
    public int DestinationCityId { get; set; }
    public string DestinationCityName { get; set; } = string.Empty;
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public DateOnly ShipmentDate { get; set; }
    public string? TrackingNo { get; set; }
    public int FreightPaymentTypeId { get; set; }
    public string FreightPaymentTypeName { get; set; } = string.Empty;
    public int? ConsignorCustomerId { get; set; }
    public string? ConsignorCustomerName { get; set; }
    public string? ConsignorName { get; set; }
    public string? ConsignorAddress { get; set; }
    public string? ConsignorPhone { get; set; }
    public int? ConsigneeCustomerId { get; set; }
    public string? ConsigneeCustomerName { get; set; }
    public string? ConsigneeName { get; set; }
    public string? ConsigneeAddress { get; set; }
    public string? ConsigneePhone { get; set; }
    public string? CnNumber { get; set; }
}

public class ShipmentItemDto
{
    public int Id { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public int UnitOfMeasureId { get; set; }
    public string UnitOfMeasureCode { get; set; } = string.Empty;
    public decimal? WeightKg { get; set; }
    public decimal? VolumeCbm { get; set; }
}

public class ShipmentDetailDto : ShipmentDto
{
    public IReadOnlyList<ShipmentItemDto> Items { get; set; } = Array.Empty<ShipmentItemDto>();
}

public class CreateShipmentItemRequest
{
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public int UnitOfMeasureId { get; set; }
    public decimal? WeightKg { get; set; }
    public decimal? VolumeCbm { get; set; }
}

public class CreateShipmentRequest
{
    // BillingParty - see ShipmentDto's comment on CustomerId.
    public int CustomerId { get; set; }
    public int OriginCityId { get; set; }
    public int DestinationCityId { get; set; }
    public int StatusId { get; set; }
    public DateOnly ShipmentDate { get; set; }
    public int? TripId { get; set; }
    public int FreightPaymentTypeId { get; set; }
    public int? ConsignorCustomerId { get; set; }
    public string? ConsignorName { get; set; }
    public string? ConsignorAddress { get; set; }
    public string? ConsignorPhone { get; set; }
    public int? ConsigneeCustomerId { get; set; }
    public string? ConsigneeName { get; set; }
    public string? ConsigneeAddress { get; set; }
    public string? ConsigneePhone { get; set; }
    public List<CreateShipmentItemRequest> Items { get; set; } = new();
}

// Header fields only - line items aren't editable through this request (see
// usp_UpdateShipment's comment); they still round-trip read-only via
// ShipmentDetailDto. The consignment note's CnNumber, once generated at
// creation, is never regenerated by an update.
public class UpdateShipmentRequest
{
    public int ShipmentId { get; set; }
    public int CustomerId { get; set; }
    public int OriginCityId { get; set; }
    public int DestinationCityId { get; set; }
    public int StatusId { get; set; }
    public DateOnly ShipmentDate { get; set; }
    public int FreightPaymentTypeId { get; set; }
    public int? ConsignorCustomerId { get; set; }
    public string? ConsignorName { get; set; }
    public string? ConsignorAddress { get; set; }
    public string? ConsignorPhone { get; set; }
    public int? ConsigneeCustomerId { get; set; }
    public string? ConsigneeName { get; set; }
    public string? ConsigneeAddress { get; set; }
    public string? ConsigneePhone { get; set; }
}

// ---- Trip expenses / advances (cost tracking, see 012_ops_phase3_schema.sql) ----

public class TripExpenseDto
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public string ExpenseType { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public DateOnly ExpenseDate { get; set; }
    public string? Notes { get; set; }
}

public class CreateTripExpenseRequest
{
    public int TripId { get; set; }
    public string ExpenseType { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public DateOnly ExpenseDate { get; set; }
    public string? Notes { get; set; }
}

public class TripAdvanceDto
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public decimal Amount { get; set; }
    public DateOnly AdvanceDate { get; set; }
    public string? Notes { get; set; }
}

public class CreateTripAdvanceRequest
{
    public int TripId { get; set; }
    public decimal Amount { get; set; }
    public DateOnly AdvanceDate { get; set; }
    public string? Notes { get; set; }
}

public class TripCostSummaryDto
{
    public int TripId { get; set; }
    public decimal TotalExpenses { get; set; }
    public decimal TotalAdvances { get; set; }
    // Positive: driver still holds unspent advance. Negative: driver spent
    // more than the advance and is owed the difference.
    public decimal Balance => TotalAdvances - TotalExpenses;

    // Sum of every ShipmentCharge (Freight/Loading/Unloading/Detention/
    // Halting/Other) for shipments carried on this trip - "customer
    // charges" in the profit formula below.
    public decimal CustomerChargesTotal { get; set; }
    // Agreed vendor freight for a Hired trip; null for an Own trip (no
    // vendor, so no vendor-freight cost to subtract).
    public decimal? VendorFreightAmount { get; set; }
    public decimal Profit => CustomerChargesTotal - (VendorFreightAmount ?? 0) - TotalExpenses;
}

// ---- Proof of delivery ----

public class ProofOfDeliveryPhotoDto
{
    public int Id { get; set; }
    public string FilePath { get; set; } = string.Empty;
}

public class ProofOfDeliveryDto
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public string ReceiverName { get; set; } = string.Empty;
    public string? ReceiverPhone { get; set; }
    public DateTime DeliveredAt { get; set; }
    public string? Notes { get; set; }
    public string? SignatureFilePath { get; set; }
    public IReadOnlyList<ProofOfDeliveryPhotoDto> Photos { get; set; } = Array.Empty<ProofOfDeliveryPhotoDto>();
}

public class CreateProofOfDeliveryRequest
{
    public int TripId { get; set; }
    public string ReceiverName { get; set; } = string.Empty;
    public string? ReceiverPhone { get; set; }
    public DateTime DeliveredAt { get; set; }
    public string? Notes { get; set; }
    public string? SignatureFilePath { get; set; }
    public List<string> PhotoFilePaths { get; set; } = new();
}

// ---- Trip document uploads ----

public class TripDocumentDto
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public string DocumentType { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public string FilePath { get; set; } = string.Empty;
    public DateTime UploadedAt { get; set; }
}

// ---- Trip incidents / delay reports ----

public class TripIncidentDto
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public string IncidentType { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime ReportedAt { get; set; }
    public string? ReportedBy { get; set; }
}

public class CreateTripIncidentRequest
{
    public int TripId { get; set; }
    public string IncidentType { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
}

// ---- Multi-stop route legs ----

public class RouteStopDto
{
    public int Id { get; set; }
    public int RouteId { get; set; }
    public int CityId { get; set; }
    public string CityName { get; set; } = string.Empty;
    public int StopOrder { get; set; }
    public DateTime? PlannedArrival { get; set; }
}

public class CreateRouteStopRequest
{
    public int RouteId { get; set; }
    public int CityId { get; set; }
    public int StopOrder { get; set; }
    public DateTime? PlannedArrival { get; set; }
}

// ---- Trip capacity check ----

// All four fields are null for a Hired trip - a hired truck's real capacity
// isn't tracked in our fleet data, so the check can't be performed at all
// (not the same thing as "checked, 0kg used, fits fine").
public class TripCapacityCheckDto
{
    public int TripId { get; set; }
    public decimal? VehicleCapacityKg { get; set; }
    public decimal? VehicleCapacityCbm { get; set; }
    public decimal? AssignedWeightKg { get; set; }
    public decimal? AssignedVolumeCbm { get; set; }
    public bool IsOverCapacity => AssignedWeightKg is not null && VehicleCapacityKg is not null && AssignedWeightKg > VehicleCapacityKg;
    public bool IsOverVolumeCapacity => AssignedVolumeCbm is not null && VehicleCapacityCbm is not null && AssignedVolumeCbm > VehicleCapacityCbm;
}

// ---- Dispatch conflict check ----

// Both null for a Hired trip being checked - it has no fleet vehicle/driver
// to conflict against, so conflict-checking simply finds nothing.
public class CheckTripConflictsRequest
{
    public int? DriverId { get; set; }
    public int? VehicleId { get; set; }
    public DateTime ScheduledDeparture { get; set; }
    public DateTime ScheduledArrival { get; set; }
    public int? ExcludeTripId { get; set; }
}

public class TripConflictDto
{
    public int Id { get; set; }
    public int RouteId { get; set; }
    public string RouteName { get; set; } = string.Empty;
    public int? VehicleId { get; set; }
    public string? RegistrationNo { get; set; }
    public int? DriverId { get; set; }
    public string? DriverName { get; set; }
    public DateTime ScheduledDeparture { get; set; }
    public DateTime ScheduledArrival { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public bool IsDriverConflict { get; set; }
    public bool IsVehicleConflict { get; set; }
}

// ---- Public shipment tracking (deliberately minimal - see usp_TrackShipment) ----

public class ShipmentTrackingDto
{
    public string TrackingNo { get; set; } = string.Empty;
    public DateOnly ShipmentDate { get; set; }
    public string OriginCityName { get; set; } = string.Empty;
    public string DestinationCityName { get; set; } = string.Empty;
    public string StatusName { get; set; } = string.Empty;
    public DateTime? ScheduledDeparture { get; set; }
    public DateTime? ScheduledArrival { get; set; }
    public DateTime? ActualDeparture { get; set; }
    public DateTime? ActualArrival { get; set; }
    public string? TripStatusName { get; set; }
}
