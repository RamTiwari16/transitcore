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
    public IReadOnlyList<string> RoleNames { get; set; } = Array.Empty<string>();
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
    public IReadOnlyList<int> RoleIds { get; set; } = Array.Empty<int>();
}

public class RoleDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
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
    public List<int> RoleIds { get; set; } = new();
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
    public bool IsActive { get; set; }
    public List<int> BranchIds { get; set; } = new();
    public List<int> RoleIds { get; set; } = new();
}

public class ResetPasswordRequest
{
    public int UserId { get; set; }
    public string NewPassword { get; set; } = string.Empty;
}

// The branch a shipment/consignment-note is booked under is resolved from
// the current user's primary branch, not entered by staff - see F1/F2's
// design notes in 014_freight_parties_consignment_notes_schema.sql. This
// only re-designates which of a user's ALREADY-assigned branches (from
// BranchIds on CreateUserRequest/UpdateUserRequest) is primary.
public class SetPrimaryBranchRequest
{
    public int BranchId { get; set; }
}
