namespace TransitCore.Domain.Fleet;

public class Vehicle
{
    public int Id { get; set; }
    public string RegistrationNo { get; set; } = string.Empty;
    public int VehicleTypeId { get; set; }
    public string? Make { get; set; }
    public string? Model { get; set; }
    public int? ManufactureYear { get; set; }
    public decimal CapacityKg { get; set; }
    public int StatusId { get; set; }
}
