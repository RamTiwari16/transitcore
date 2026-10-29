namespace TransitCore.Application.Models;

public class TripStopShipmentDto
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public int ShipmentId { get; set; }
    public string? TrackingNo { get; set; }
    public int CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string Action { get; set; } = string.Empty;
    public string StopType { get; set; } = string.Empty;
    public int? RouteStopId { get; set; }
    public string StopCityName { get; set; } = string.Empty;
    public int SortKey { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
}

public class CreateTripStopShipmentRequest
{
    public int TripId { get; set; }
    public int ShipmentId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string StopType { get; set; } = string.Empty;
    public int? RouteStopId { get; set; }
}
