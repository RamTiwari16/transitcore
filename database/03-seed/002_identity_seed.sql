/*
  Purpose:      Identity seed data — roles, permissions, and demo users.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 001_lookup_seed.sql, 002_identity_schema.sql

  Demo user passwords (for local/dev login only — rotate before any shared
  environment): admin@transitcore.local / Admin@123
                 manager@transitcore.local / Manager@123
                 ops@transitcore.local / User@123
  Hashes below were generated with the exact PBKDF2-HMACSHA256 (100,000
  iterations, 16-byte salt, 32-byte key) algorithm used by
  TransitCore.Infrastructure.Security.PasswordHasher — see that class if you
  need to generate hashes for additional seed users.
*/
SET NOCOUNT ON;
GO

MERGE auth.Roles AS target
USING (VALUES ('Admin'), ('Manager'), ('User')) AS source (Name)
ON target.Name = source.Name
WHEN NOT MATCHED THEN
    INSERT (Name, CreatedBy) VALUES (source.Name, 'seed');
GO

MERGE auth.Permissions AS target
USING (VALUES
    ('users.manage'), ('users.view'),
    ('fleet.manage'), ('fleet.view'),
    ('trips.manage'), ('trips.view'),
    ('billing.manage'), ('billing.view')
) AS source (Name)
ON target.Name = source.Name
WHEN NOT MATCHED THEN
    INSERT (Name, CreatedBy) VALUES (source.Name, 'seed');
GO

INSERT INTO auth.RolePermissions (RoleId, PermissionId)
SELECT r.Id, p.Id
FROM auth.Roles r
CROSS JOIN auth.Permissions p
WHERE r.Name = 'Admin'
  AND NOT EXISTS (
      SELECT 1 FROM auth.RolePermissions rp WHERE rp.RoleId = r.Id AND rp.PermissionId = p.Id
  );
GO

INSERT INTO auth.RolePermissions (RoleId, PermissionId)
SELECT r.Id, p.Id
FROM auth.Roles r
CROSS JOIN auth.Permissions p
WHERE r.Name = 'Manager'
  AND p.Name IN ('users.view', 'fleet.manage', 'fleet.view', 'trips.manage', 'trips.view', 'billing.view')
  AND NOT EXISTS (
      SELECT 1 FROM auth.RolePermissions rp WHERE rp.RoleId = r.Id AND rp.PermissionId = p.Id
  );
GO

INSERT INTO auth.RolePermissions (RoleId, PermissionId)
SELECT r.Id, p.Id
FROM auth.Roles r
CROSS JOIN auth.Permissions p
WHERE r.Name = 'User'
  AND p.Name IN ('fleet.view', 'trips.view')
  AND NOT EXISTS (
      SELECT 1 FROM auth.RolePermissions rp WHERE rp.RoleId = r.Id AND rp.PermissionId = p.Id
  );
GO

MERGE auth.Users AS target
USING (VALUES
    ('admin@transitcore.local',   '73DVYAcCOIPZq50VMeD1wg==', 'I7u477jyEFjXJclxjQ63538irJh9IDduDR/OCWnE0mY=', 'System Administrator'),
    ('manager@transitcore.local', 'BSDUUd0rmPQeCNDhMygB/A==', 'FvQqbLmBUAI5EKoue6sU/Da6NCs0tI38u/dAdu8vnpU=', 'Regional Manager'),
    ('ops@transitcore.local',     'e8kLOIwa0QwNDf2whKXCqg==', 'NYEgdiMC0VrIhMOQo4shsNCQH+uLSD0J2FelXCyGN2A=', 'Operations User')
) AS source (Email, PasswordSalt, PasswordHash, DisplayName)
ON target.Email = source.Email
WHEN NOT MATCHED THEN
    INSERT (Email, PasswordHash, PasswordSalt, DisplayName, IsActive, CreatedBy)
    VALUES (source.Email, source.PasswordHash, source.PasswordSalt, source.DisplayName, 1, 'seed');
GO

INSERT INTO auth.UserRoles (UserId, RoleId)
SELECT u.Id, r.Id
FROM auth.Users u
CROSS JOIN auth.Roles r
WHERE (
          (u.Email = 'admin@transitcore.local'   AND r.Name = 'Admin')
       OR (u.Email = 'manager@transitcore.local' AND r.Name = 'Manager')
       OR (u.Email = 'ops@transitcore.local'     AND r.Name = 'User')
      )
  AND NOT EXISTS (
      SELECT 1 FROM auth.UserRoles ur WHERE ur.UserId = u.Id AND ur.RoleId = r.Id
  );
GO
