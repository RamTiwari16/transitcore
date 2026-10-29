namespace TransitCore.Application.Models;

public class SearchResultDto
{
    public string EntityType { get; set; } = string.Empty;
    public int EntityId { get; set; }
    public string Label { get; set; } = string.Empty;
    public string? SubLabel { get; set; }
}
