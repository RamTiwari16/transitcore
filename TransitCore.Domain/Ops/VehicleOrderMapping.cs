namespace TransitCore.Domain.Ops;

public class VehicleOrderMapping
{
    public int Id { get; set; }
    public string VehicleNo { get; set; } = string.Empty;
    public string OrderNo { get; set; } = string.Empty;
    public DateOnly UploadDate { get; set; }
    public string CreatedByEmail { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}
