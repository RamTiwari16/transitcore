using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IUserManagementService
{
    Task<IReadOnlyList<UserSummaryDto>> GetUsersAsync(UserFilterRequest filter, CancellationToken cancellationToken = default);
    Task<UserDetailDto?> GetUserByIdAsync(int userId, CancellationToken cancellationToken = default);
    Task<int> CreateUserAsync(CreateUserRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateUserAsync(UpdateUserRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<RoleDto>> GetRolesAsync(CancellationToken cancellationToken = default);
    Task<bool> ResetPasswordAsync(ResetPasswordRequest request, string modifiedBy, CancellationToken cancellationToken = default);

    Task<int?> GetPrimaryBranchIdAsync(int userId, CancellationToken cancellationToken = default);
    Task<bool> SetPrimaryBranchAsync(int userId, SetPrimaryBranchRequest request, CancellationToken cancellationToken = default);
}
