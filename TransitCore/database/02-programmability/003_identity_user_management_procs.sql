/*
  Purpose:      User management procedures — list/filter, get by id (with
                branch assignments), insert, update.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 002_identity_schema.sql, 003_identity_tvp.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
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
            ) AS BranchNames
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
    @Branches             auth.IntList_TVP READONLY
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

        INSERT INTO auth.UserBranches (UserId, BranchId)
        SELECT @NewUserId, Id FROM @Branches;

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
    @ModifiedBy           NVARCHAR(256),
    @Branches             auth.IntList_TVP READONLY,
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
            ModifiedBy           = @ModifiedBy,
            ModifiedAt           = SYSUTCDATETIME()
        WHERE Id = @UserId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;

        DELETE FROM auth.UserBranches WHERE UserId = @UserId;

        INSERT INTO auth.UserBranches (UserId, BranchId)
        SELECT @UserId, Id FROM @Branches;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
