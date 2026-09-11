namespace TransitCore.Application.Models;

public class UserFilterRequest
{
    public int? BranchId { get; set; }
    public int? DesignationId { get; set; }
    public int? WorkingDesignationId { get; set; }
}

public class UserSummaryDto
{
    public int Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? EmpCode { get; set; }
    public int? DesignationId { get; set; }
    public string? DesignationName { get; set; }
    public int? WorkingDesignationId { get; set; }
    public string? WorkingDesignationName { get; set; }
    public int? RegionId { get; set; }
    public string? RegionName { get; set; }
    public string? PunchLocation { get; set; }
    public string? Shift { get; set; }
    public string? Company { get; set; }
    public bool IsActive { get; set; }
    public IReadOnlyList<string> BranchNames { get; set; } = Array.Empty<string>();
}

public class UserDetailDto
{
    public int Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? PhoneNo { get; set; }
    public string? EmpCode { get; set; }
    public int? DesignationId { get; set; }
    public string? DesignationName { get; set; }
    public int? WorkingDesignationId { get; set; }
    public string? WorkingDesignationName { get; set; }
    public int? RegionId { get; set; }
    public string? RegionName { get; set; }
    public string? PunchLocation { get; set; }
    public string? Shift { get; set; }
    public string? Company { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public IReadOnlyList<int> BranchIds { get; set; } = Array.Empty<int>();
}

public class CreateUserRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? PhoneNo { get; set; }
    public string? EmpCode { get; set; }
    public int? DesignationId { get; set; }
    public int? WorkingDesignationId { get; set; }
    public int? RegionId { get; set; }
    public string? PunchLocation { get; set; }
    public string? Shift { get; set; }
    public string? Company { get; set; }
    public List<int> BranchIds { get; set; } = new();
}

public class UpdateUserRequest
{
    public int UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string? PhoneNo { get; set; }
    public int? DesignationId { get; set; }
    public int? WorkingDesignationId { get; set; }
    public int? RegionId { get; set; }
    public string? PunchLocation { get; set; }
    public string? Shift { get; set; }
    public string? Company { get; set; }
    public List<int> BranchIds { get; set; } = new();
}
