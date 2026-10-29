namespace TransitCore.Domain.Ops;

public class Route
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int OriginCityId { get; set; }
    public int DestinationCityId { get; set; }
    public decimal? DistanceKm { get; set; }
}
