namespace TransitCore.Domain.Ops;

public class Shipment
{
    public int Id { get; set; }
    public int? TripId { get; set; }
    public int CustomerId { get; set; }
    public int OriginCityId { get; set; }
    public int DestinationCityId { get; set; }
    public int StatusId { get; set; }
    public DateOnly ShipmentDate { get; set; }
}

public class ShipmentItem
{
    public int Id { get; set; }
    public int ShipmentId { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public int UnitOfMeasureId { get; set; }
    public decimal? WeightKg { get; set; }
}
