namespace TransitCore.Domain.Identity;

public class User
{
    public int Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string PasswordSalt { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? PhoneNo { get; set; }
    public string? EmpCode { get; set; }
    public int? DesignationId { get; set; }
    public int? WorkingDesignationId { get; set; }
    public int? RegionId { get; set; }
    public string? PunchLocation { get; set; }
    public string? Shift { get; set; }
    public string? Company { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime? ModifiedAt { get; set; }
    public string? ModifiedBy { get; set; }
}
