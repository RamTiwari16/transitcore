using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;

namespace TransitCore.Api.Controllers;

[Authorize]
[Route("api/v1/[controller]")]
[ApiController]
public class UserManagementController : ControllerBase
{
    private readonly IUserManagementService _userManagementService;

    public UserManagementController(IUserManagementService userManagementService)
    {
        _userManagementService = userManagementService;
    }

    [HttpGet]
    public async Task<IActionResult> GetUsers([FromQuery] UserFilterRequest filter, CancellationToken cancellationToken)
    {
        var users = await _userManagementService.GetUsersAsync(filter, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<UserSummaryDto>>.Ok(users));
    }

    [HttpGet("{userId:int}")]
    public async Task<IActionResult> GetUserById(int userId, CancellationToken cancellationToken)
    {
        var user = await _userManagementService.GetUserByIdAsync(userId, cancellationToken);

        if (user is null)
            return NotFound(ApiResponse<string>.Fail("User not found"));

        return Ok(ApiResponse<UserDetailDto>.Ok(user));
    }

    [HttpPost]
    public async Task<IActionResult> CreateUser([FromBody] CreateUserRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newUserId = await _userManagementService.CreateUserAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newUserId, "User created successfully"));
    }

    [HttpPut]
    public async Task<IActionResult> UpdateUser([FromBody] UpdateUserRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _userManagementService.UpdateUserAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("User not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "User updated successfully"));
    }
}
