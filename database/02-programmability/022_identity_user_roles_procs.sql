/*
  Purpose:      Phase 5 (Admin) - adds role assignment, IsActive toggle, and
                password reset to user management. Regenerates
                usp_GetUsers/usp_GetUserById/usp_InsertUser/usp_UpdateUser
                from 003_identity_user_management_procs.sql to add role
                support (mirrors how Branches is already handled via
                auth.IntList_TVP), and adds usp_GetRoles / usp_ResetUserPassword.
  Author:       TransitCore rebuild
  Date:         2026-09-15
  Dependencies: 002_identity_schema.sql, 003_identity_tvp.sql,
                003_identity_user_management_procs.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('auth.usp_GetRoles', 'P') IS NOT NULL
    DROP PROCEDURE auth.usp_GetRoles;
GO

CREATE PROCEDURE auth.usp_GetRoles
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Name
        FROM auth.Roles
        WHERE IsDeleted = 0
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('auth.usp_GetUsers', 'P') IS NOT NULL
    DROP PROCEDURE auth.usp_GetUsers;
GO

CREATE PROCEDURE auth.usp_GetUsers
    @BranchId             INT = NULL,
    @DesignationId        INT = NULL,
    @WorkingDesignationId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            u.Id,
            u.Email,
            u.DisplayName,
            u.EmpCode,
            u.DesignationId,
            d.Name AS DesignationName,
            u.WorkingDesignationId,
            wd.Name AS WorkingDesignationName,
            u.RegionId,
            rg.Name AS RegionName,
            u.PunchLocation,
            u.Shift,
            u.Company,
            u.IsActive,
            (
                SELECT STRING_AGG(br.Name, ',')
                FROM auth.UserBranches ub2
                INNER JOIN lookup.Branches br ON br.Id = ub2.BranchId
                WHERE ub2.UserId = u.Id
            ) AS BranchNames,
            (
                SELECT STRING_AGG(r.Name, ',')
                FROM auth.UserRoles ur2
                INNER JOIN auth.Roles r ON r.Id = ur2.RoleId
                WHERE ur2.UserId = u.Id AND r.IsDeleted = 0
            ) AS RoleNames
        FROM auth.Users u
        LEFT JOIN lookup.Designations d ON d.Id = u.DesignationId
        LEFT JOIN lookup.WorkingDesignations wd ON wd.Id = u.WorkingDesignationId
        LEFT JOIN lookup.Regions rg ON rg.Id = u.RegionId
        WHERE u.IsDeleted = 0
          AND (@DesignationId IS NULL OR u.DesignationId = @DesignationId)
          AND (@WorkingDesignationId IS NULL OR u.WorkingDesignationId = @WorkingDesignationId)
          AND (
                @BranchId IS NULL
                OR EXISTS (SELECT 1 FROM auth.UserBranches ub WHERE ub.UserId = u.Id AND ub.BranchId = @BranchId)
              )
        ORDER BY u.DisplayName;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('auth.usp_GetUserById', 'P') IS NOT NULL
    DROP PROCEDURE auth.usp_GetUserById;
GO

CREATE PROCEDURE auth.usp_GetUserById
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            u.Id, u.Email, u.DisplayName, u.PhoneNo, u.EmpCode,
            u.DesignationId, d.Name AS DesignationName,
            u.WorkingDesignationId, wd.Name AS WorkingDesignationName,
            u.RegionId, rg.Name AS RegionName,
            u.PunchLocation, u.Shift, u.Company, u.IsActive,
            u.CreatedAt, u.CreatedBy
        FROM auth.Users u
        LEFT JOIN lookup.Designations d ON d.Id = u.DesignationId
        LEFT JOIN lookup.WorkingDesignations wd ON wd.Id = u.WorkingDesignationId
        LEFT JOIN lookup.Regions rg ON rg.Id = u.RegionId
        WHERE u.Id = @UserId AND u.IsDeleted = 0;

        SELECT BranchId
        FROM auth.UserBranches
        WHERE UserId = @UserId;

        SELECT RoleId
        FROM auth.UserRoles
        WHERE UserId = @UserId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('auth.usp_InsertUser', 'P') IS NOT NULL
    DROP PROCEDURE auth.usp_InsertUser;
GO

CREATE PROCEDURE auth.usp_InsertUser
    @Email                NVARCHAR(256),
    @PasswordHash         NVARCHAR(256),
    @PasswordSalt         NVARCHAR(256),
    @DisplayName          NVARCHAR(200),
    @PhoneNo              NVARCHAR(30)  = NULL,
    @EmpCode              NVARCHAR(50)  = NULL,
    @DesignationId        INT           = NULL,
    @WorkingDesignationId INT           = NULL,
    @RegionId             INT           = NULL,
    @PunchLocation        NVARCHAR(200) = NULL,
    @Shift                NVARCHAR(50)  = NULL,
    @Company              NVARCHAR(200) = NULL,
    @CreatedBy            NVARCHAR(256),
    @Branches             auth.IntList_TVP READONLY,
    @Roles                auth.IntList_TVP READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO auth.Users
            (Email, PasswordHash, PasswordSalt, DisplayName, PhoneNo, EmpCode,
             DesignationId, WorkingDesignationId, RegionId, PunchLocation, Shift, Company, CreatedBy)
        VALUES
            (@Email, @PasswordHash, @PasswordSalt, @DisplayName, @PhoneNo, @EmpCode,
             @DesignationId, @WorkingDesignationId, @RegionId, @PunchLocation, @Shift, @Company, @CreatedBy);

        DECLARE @NewUserId INT = SCOPE_IDENTITY();

        -- Shipment creation numbers consignment notes from the creator's
        -- primary branch, so any user with branches must have exactly one.
        INSERT INTO auth.UserBranches (UserId, BranchId, IsPrimary)
        SELECT @NewUserId, Id, CASE WHEN Id = (SELECT MIN(Id) FROM @Branches) THEN 1 ELSE 0 END
        FROM @Branches;

        INSERT INTO auth.UserRoles (UserId, RoleId)
        SELECT @NewUserId, Id FROM @Roles;

        COMMIT TRANSACTION;

        SELECT @NewUserId AS UserId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('auth.usp_UpdateUser', 'P') IS NOT NULL
    DROP PROCEDURE auth.usp_UpdateUser;
GO

CREATE PROCEDURE auth.usp_UpdateUser
    @UserId               INT,
    @DisplayName          NVARCHAR(200),
    @PhoneNo              NVARCHAR(30)  = NULL,
    @DesignationId        INT           = NULL,
    @WorkingDesignationId INT           = NULL,
    @RegionId             INT           = NULL,
    @PunchLocation        NVARCHAR(200) = NULL,
    @Shift                NVARCHAR(50)  = NULL,
    @Company              NVARCHAR(200) = NULL,
    @IsActive             BIT,
    @ModifiedBy           NVARCHAR(256),
    @Branches             auth.IntList_TVP READONLY,
    @Roles                auth.IntList_TVP READONLY,
    @IsUpdated            BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE auth.Users
        SET DisplayName          = @DisplayName,
            PhoneNo              = @PhoneNo,
            DesignationId        = @DesignationId,
            WorkingDesignationId = @WorkingDesignationId,
            RegionId             = @RegionId,
            PunchLocation        = @PunchLocation,
            Shift                = @Shift,
            Company              = @Company,
            IsActive             = @IsActive,
            ModifiedBy           = @ModifiedBy,
            ModifiedAt           = SYSUTCDATETIME()
        WHERE Id = @UserId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;

        -- Keep the current primary branch if it's still assigned; otherwise
        -- fall back to the lowest branch so the user always has exactly one.
        DECLARE @PrimaryBranchId INT = (
            SELECT ub.BranchId
            FROM auth.UserBranches ub
            INNER JOIN @Branches b ON b.Id = ub.BranchId
            WHERE ub.UserId = @UserId AND ub.IsPrimary = 1
        );
        IF @PrimaryBranchId IS NULL
            SET @PrimaryBranchId = (SELECT MIN(Id) FROM @Branches);

        DELETE FROM auth.UserBranches WHERE UserId = @UserId;

        INSERT INTO auth.UserBranches (UserId, BranchId, IsPrimary)
        SELECT @UserId, Id, CASE WHEN Id = @PrimaryBranchId THEN 1 ELSE 0 END
        FROM @Branches;

        DELETE FROM auth.UserRoles WHERE UserId = @UserId;

        INSERT INTO auth.UserRoles (UserId, RoleId)
        SELECT @UserId, Id FROM @Roles;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('auth.usp_ResetUserPassword', 'P') IS NOT NULL
    DROP PROCEDURE auth.usp_ResetUserPassword;
GO

CREATE PROCEDURE auth.usp_ResetUserPassword
    @UserId       INT,
    @PasswordHash NVARCHAR(256),
    @PasswordSalt NVARCHAR(256),
    @ModifiedBy   NVARCHAR(256),
    @IsUpdated    BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE auth.Users
        SET PasswordHash = @PasswordHash,
            PasswordSalt = @PasswordSalt,
            ModifiedBy   = @ModifiedBy,
            ModifiedAt   = SYSUTCDATETIME()
        WHERE Id = @UserId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
