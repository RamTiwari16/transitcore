namespace TransitCore.Domain.Fleet;

public class Driver
{
    public int Id { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? PhoneNo { get; set; }
    public string? Email { get; set; }
    public DateOnly? HireDate { get; set; }
    public int StatusId { get; set; }
}
