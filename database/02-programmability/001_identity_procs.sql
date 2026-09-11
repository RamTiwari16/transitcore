/*
  Purpose:      Stored procedures for the Identity/login slice.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 001_lookup_core.sql, 002_identity_schema.sql

  Note on password verification: this procedure returns the stored
  PasswordHash/PasswordSalt for the given email; the actual PBKDF2
  comparison happens in TransitCore.Infrastructure (IPasswordHasher), not in
  T-SQL. That keeps the hashing algorithm's iteration count/parameters easy
  to change without touching the database.
*/
SET NOCOUNT ON;
GO

IF OBJECT_ID('identity.usp_GetUserForLogin', 'P') IS NOT NULL
    DROP PROCEDURE identity.usp_GetUserForLogin;
GO

CREATE PROCEDURE identity.usp_GetUserForLogin
    @Email NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            u.Id,
            u.Email,
            u.PasswordHash,
            u.PasswordSalt,
            u.DisplayName,
            u.IsActive,
            (
                SELECT STRING_AGG(r.Name, ',')
                FROM identity.UserRoles ur
                INNER JOIN identity.Roles r ON r.Id = ur.RoleId
                WHERE ur.UserId = u.Id AND r.IsDeleted = 0
            ) AS Roles
        FROM identity.Users u
        WHERE u.Email = @Email
          AND u.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
