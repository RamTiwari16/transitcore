namespace TransitCore.Application.Jwt;

public interface IJwtTokenGenerator
{
    (string Token, DateTime ExpiresAtUtc) GenerateToken(int userId, string email, IEnumerable<string> roles);
}
