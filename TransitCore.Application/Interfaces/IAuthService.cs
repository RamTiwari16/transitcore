using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IAuthService
{
    Task<AuthResult?> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default);
}
