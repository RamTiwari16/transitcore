/*
  Purpose:      Read stored procedures for the lookup domain (regions,
                branches, designations, working designations).
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 001_lookup_core.sql
*/
SET NOCOUNT ON;
GO

IF OBJECT_ID('lookup.usp_GetRegions', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_GetRegions;
GO

CREATE PROCEDURE lookup.usp_GetRegions
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Name
        FROM lookup.Regions
        WHERE IsDeleted = 0
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_GetBranches', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_GetBranches;
GO

CREATE PROCEDURE lookup.usp_GetBranches
    @RegionId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT b.Id, b.Name, b.RegionId, r.Name AS RegionName
        FROM lookup.Branches b
        INNER JOIN lookup.Regions r ON r.Id = b.RegionId
        WHERE b.IsDeleted = 0
          AND (@RegionId IS NULL OR b.RegionId = @RegionId)
        ORDER BY b.Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_GetDesignations', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_GetDesignations;
GO

CREATE PROCEDURE lookup.usp_GetDesignations
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Code, Name
        FROM lookup.Designations
        WHERE IsDeleted = 0
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_GetWorkingDesignations', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_GetWorkingDesignations;
GO

CREATE PROCEDURE lookup.usp_GetWorkingDesignations
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Name
        FROM lookup.WorkingDesignations
        WHERE IsDeleted = 0
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
