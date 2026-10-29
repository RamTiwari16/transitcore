namespace TransitCore.Application.Models;

public class VehicleTypeDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal CapacityKg { get; set; }
    public decimal CapacityCbm { get; set; }
}

public class VehicleDto
{
    public int Id { get; set; }
    public string RegistrationNo { get; set; } = string.Empty;
    public int VehicleTypeId { get; set; }
    public string VehicleTypeName { get; set; } = string.Empty;
    public string? Make { get; set; }
    public string? Model { get; set; }
    public int? ManufactureYear { get; set; }
    public decimal CapacityKg { get; set; }
    public decimal CapacityCbm { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
}

public class CreateVehicleRequest
{
    public string RegistrationNo { get; set; } = string.Empty;
    public int VehicleTypeId { get; set; }
    public string? Make { get; set; }
    public string? Model { get; set; }
    public int? ManufactureYear { get; set; }
    public decimal CapacityKg { get; set; }
    public decimal CapacityCbm { get; set; }
    public int StatusId { get; set; }
}

public class UpdateVehicleRequest
{
    public int VehicleId { get; set; }
    public int VehicleTypeId { get; set; }
    public string? Make { get; set; }
    public string? Model { get; set; }
    public int? ManufactureYear { get; set; }
    public decimal CapacityKg { get; set; }
    public decimal CapacityCbm { get; set; }
    public int StatusId { get; set; }
}

public class DriverDto
{
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? PhoneNo { get; set; }
    public string? Email { get; set; }
    public DateOnly? HireDate { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
}

public class CreateDriverRequest
{
    public string FullName { get; set; } = string.Empty;
    public string? PhoneNo { get; set; }
    public string? Email { get; set; }
    public DateOnly? DateOfBirth { get; set; }
    public DateOnly? HireDate { get; set; }
    public int StatusId { get; set; }
}

// Separate from DriverDto (the list shape) rather than adding DateOfBirth to
// it directly - same "detail extends list" convention as TripDetailDto/
// ShipmentDetailDto, so the list endpoint's payload doesn't grow for a field
// only the edit form needs.
public class DriverDetailDto : DriverDto
{
    public DateOnly? DateOfBirth { get; set; }
}

public class UpdateDriverRequest
{
    public int DriverId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? PhoneNo { get; set; }
    public string? Email { get; set; }
    public DateOnly? DateOfBirth { get; set; }
    public DateOnly? HireDate { get; set; }
    public int StatusId { get; set; }
}

// ---- Vehicle documents (registration, insurance, permit, PUC, etc.) ----

public class VehicleDocumentDto
{
    public int Id { get; set; }
    public int VehicleId { get; set; }
    public string DocumentType { get; set; } = string.Empty;
    public string? DocumentNo { get; set; }
    public DateOnly? IssuedDate { get; set; }
    public DateOnly? ExpiryDate { get; set; }
}

public class CreateVehicleDocumentRequest
{
    public int VehicleId { get; set; }
    public string DocumentType { get; set; } = string.Empty;
    public string? DocumentNo { get; set; }
    public DateOnly? IssuedDate { get; set; }
    public DateOnly? ExpiryDate { get; set; }
}

public class ExpiringVehicleDocumentDto
{
    public int Id { get; set; }
    public int VehicleId { get; set; }
    public string RegistrationNo { get; set; } = string.Empty;
    public string DocumentType { get; set; } = string.Empty;
    public string? DocumentNo { get; set; }
    public DateOnly ExpiryDate { get; set; }
}

// ---- Maintenance / service history ----

public class MaintenanceRecordDto
{
    public int Id { get; set; }
    public int VehicleId { get; set; }
    public DateOnly ServiceDate { get; set; }
    public string? Description { get; set; }
    public decimal Cost { get; set; }
    public int? OdometerKm { get; set; }
    public string? PerformedBy { get; set; }
}

public class CreateMaintenanceRecordRequest
{
    public int VehicleId { get; set; }
    public DateOnly ServiceDate { get; set; }
    public string? Description { get; set; }
    public decimal Cost { get; set; }
    public int? OdometerKm { get; set; }
    public string? PerformedBy { get; set; }
}

// ---- Fuel logs ----

public class FuelLogDto
{
    public int Id { get; set; }
    public int VehicleId { get; set; }
    public DateOnly FuelDate { get; set; }
    public decimal Liters { get; set; }
    public decimal Cost { get; set; }
    public int? OdometerKm { get; set; }
    // Distance since the previous log's odometer reading, divided by this
    // fill's liters - null when there's no previous reading (first log, or
    // either reading is missing) to diff against.
    public decimal? KmPerLiter { get; set; }
}

public class CreateFuelLogRequest
{
    public int VehicleId { get; set; }
    public DateOnly FuelDate { get; set; }
    public decimal Liters { get; set; }
    public decimal Cost { get; set; }
    public int? OdometerKm { get; set; }
}

// ---- Driver licences / medical certificates ----
// LicenseType is free text ("Driving License", "Medical Certificate", ...)
// rather than two separate tables, since both are structurally identical: a
// document with an expiry date to track.

public class DriverLicenseDto
{
    public int Id { get; set; }
    public int DriverId { get; set; }
    public string LicenseNo { get; set; } = string.Empty;
    public string? LicenseType { get; set; }
    public DateOnly? IssuedDate { get; set; }
    public DateOnly? ExpiryDate { get; set; }
}

public class CreateDriverLicenseRequest
{
    public int DriverId { get; set; }
    public string LicenseNo { get; set; } = string.Empty;
    public string? LicenseType { get; set; }
    public DateOnly? IssuedDate { get; set; }
    public DateOnly? ExpiryDate { get; set; }
}

public class ExpiringDriverLicenseDto
{
    public int Id { get; set; }
    public int DriverId { get; set; }
    public string DriverName { get; set; } = string.Empty;
    public string? LicenseType { get; set; }
    public string LicenseNo { get; set; } = string.Empty;
    public DateOnly ExpiryDate { get; set; }
}

// ---- Driver performance (derived from ops.Trips, no dedicated table) ----

public class DriverPerformanceDto
{
    public int DriverId { get; set; }
    public int TotalTrips { get; set; }
    public int CompletedTrips { get; set; }
    public int OnTimeTrips { get; set; }
    public int DelayedTrips { get; set; }
    public decimal TotalDistanceKm { get; set; }
    // Null (not 0) when CompletedTrips is 0 - "no completed trips yet" reads
    // differently from "0% on-time", and the UI should say so rather than
    // implying a track record that doesn't exist.
    public decimal? OnTimePercent { get; set; }
}

// ---- Driver settlement (Phase 4 Billing depth) - advances vs expenses
// across EVERY trip a driver has, not just one (compare to
// TripCostSummaryDto, the single-trip version from Phase 3). ----

public class DriverSettlementDto
{
    public int DriverId { get; set; }
    public decimal TotalAdvances { get; set; }
    public decimal TotalExpenses { get; set; }
    public int TripsWithActivity { get; set; }
    // Positive: driver still holds unspent advance overall. Negative: driver
    // is owed the difference (same sign convention as TripCostSummaryDto.Balance).
    public decimal Balance => TotalAdvances - TotalExpenses;
}

public class FleetUtilisationDto
{
    public int VehicleId { get; set; }
    public string RegistrationNo { get; set; } = string.Empty;
    public string VehicleTypeName { get; set; } = string.Empty;
    public int TotalTrips { get; set; }
    public decimal ScheduledHours { get; set; }
    public decimal UtilisationPercent { get; set; }
}
