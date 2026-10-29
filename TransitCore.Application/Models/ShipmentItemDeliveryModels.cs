namespace TransitCore.Application.Models;

public class ShipmentItemDeliveryPhotoDto
{
    public int Id { get; set; }
    public string FilePath { get; set; } = string.Empty;
}

public class ShipmentItemDeliveryDto
{
    public int DeliveryId { get; set; }
    public decimal DeliveredQty { get; set; }
    public decimal ShortQty { get; set; }
    public decimal DamagedQty { get; set; }
    public string? Remarks { get; set; }
    public DateTime RecordedAt { get; set; }
    public IReadOnlyList<ShipmentItemDeliveryPhotoDto> Photos { get; set; } = Array.Empty<ShipmentItemDeliveryPhotoDto>();
}

// One row per item on the shipment - Delivery is null until reconciliation
// has actually been recorded for that item.
public class ShipmentItemDeliveryLineDto
{
    public int ShipmentItemId { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public string UnitOfMeasureCode { get; set; } = string.Empty;
    public decimal? WeightKg { get; set; }
    public decimal? VolumeCbm { get; set; }
    public ShipmentItemDeliveryDto? Delivery { get; set; }
}

public class CreateShipmentItemDeliveryRequest
{
    public int ShipmentItemId { get; set; }
    public decimal DeliveredQty { get; set; }
    public decimal ShortQty { get; set; }
    public decimal DamagedQty { get; set; }
    public string? Remarks { get; set; }
    public List<string> PhotoFilePaths { get; set; } = new();
}

public class UpdateShipmentItemDeliveryRequest
{
    public int DeliveryId { get; set; }
    public decimal DeliveredQty { get; set; }
    public decimal ShortQty { get; set; }
    public decimal DamagedQty { get; set; }
    public string? Remarks { get; set; }
}
