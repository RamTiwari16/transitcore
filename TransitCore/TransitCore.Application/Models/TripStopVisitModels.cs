namespace TransitCore.Application.Models;

public class TripStopVisitDto
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public string StopType { get; set; } = string.Empty;
    public int? RouteStopId { get; set; }
    public string StopCityName { get; set; } = string.Empty;
    public DateTime? ArrivedAt { get; set; }
    public DateTime? DepartedAt { get; set; }
    public decimal? DwellHours { get; set; }
}

public class UpsertTripStopVisitRequest
{
    public int TripId { get; set; }
    public string StopType { get; set; } = string.Empty;
    public int? RouteStopId { get; set; }
    public DateTime? ArrivedAt { get; set; }
    public DateTime? DepartedAt { get; set; }
}
