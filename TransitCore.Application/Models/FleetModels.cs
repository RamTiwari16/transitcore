namespace TransitCore.Application.Models;

public class VehicleTypeDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal CapacityKg { get; set; }
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

public class FleetUtilisationDto
{
    public int VehicleId { get; set; }
    public string RegistrationNo { get; set; } = string.Empty;
    public string VehicleTypeName { get; set; } = string.Empty;
    public int TotalTrips { get; set; }
    public decimal ScheduledHours { get; set; }
    public decimal UtilisationPercent { get; set; }
}
