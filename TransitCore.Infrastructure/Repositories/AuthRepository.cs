using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Jwt;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class AuthRepository : IAuthService
{
    private readonly SqlDataAccess _db;
    private readonly IPasswordHasher _passwordHasher;
    private readonly IJwtTokenGenerator _tokenGenerator;

    public AuthRepository(SqlDataAccess db, IPasswordHasher passwordHasher, IJwtTokenGenerator tokenGenerator)
    {
        _db = db;
        _passwordHasher = passwordHasher;
        _tokenGenerator = tokenGenerator;
    }

    public async Task<AuthResult?> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@Email", request.Email) };

        var table = await _db.QueryProcedureAsync("auth.usp_GetUserForLogin", parameters, cancellationToken);

        if (table.Rows.Count == 0)
            return null;

        var row = table.Rows[0];

        if (!Convert.ToBoolean(row["IsActive"]))
            return null;

        var storedHash = row["PasswordHash"].ToString() ?? string.Empty;
        var storedSalt = row["PasswordSalt"].ToString() ?? string.Empty;

        if (!_passwordHasher.VerifyPassword(request.Password, storedHash, storedSalt))
            return null;

        var userId = Convert.ToInt32(row["Id"]);
        var email = row["Email"].ToString() ?? string.Empty;
        var displayName = row["DisplayName"].ToString() ?? string.Empty;

        var roles = row["Roles"] == DBNull.Value
            ? Array.Empty<string>()
            : row["Roles"]!.ToString()!.Split(',', StringSplitOptions.RemoveEmptyEntries);

        var (token, expiresAtUtc) = _tokenGenerator.GenerateToken(userId, email, roles);

        return new AuthResult
        {
            UserId = userId,
            Email = email,
            DisplayName = displayName,
            Roles = roles,
            AccessToken = token,
            ExpiresAtUtc = expiresAtUtc
        };
    }
}
