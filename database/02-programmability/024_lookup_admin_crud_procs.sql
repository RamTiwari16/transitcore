/*
  Purpose:      Admin CRUD (insert/update/soft-delete) stored procedures for
                the 8 lookup tables (Regions, Branches, Designations,
                WorkingDesignations, Countries, Cities, StatusCodes,
                UnitsOfMeasure), plus two new read procs (usp_GetCountries,
                usp_GetAllStatusCodes) that had no admin-facing read proc yet.
                Existing read procs for the other 6 tables already live in
                002_lookup_procs.sql / 010_lookup_cities_proc.sql /
                011_lookup_unitsofmeasure_proc.sql and are not touched here.
  Author:       TransitCore rebuild
  Date:         2026-09-15
  Dependencies: 001_lookup_core.sql, 005_lookup_extended.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== lookup.Regions ==========

IF OBJECT_ID('lookup.usp_InsertRegion', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_InsertRegion;
GO

CREATE PROCEDURE lookup.usp_InsertRegion
    @Name       NVARCHAR(200),
    @CreatedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO lookup.Regions (Name, CreatedBy)
        VALUES (@Name, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_UpdateRegion', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_UpdateRegion;
GO

CREATE PROCEDURE lookup.usp_UpdateRegion
    @Id          INT,
    @Name        NVARCHAR(200),
    @ModifiedBy  NVARCHAR(256),
    @IsUpdated   BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Regions
        SET Name       = @Name,
            ModifiedBy = @ModifiedBy,
            ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_DeleteRegion', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_DeleteRegion;
GO

CREATE PROCEDURE lookup.usp_DeleteRegion
    @Id          INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Regions
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== lookup.Branches ==========

IF OBJECT_ID('lookup.usp_InsertBranch', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_InsertBranch;
GO

CREATE PROCEDURE lookup.usp_InsertBranch
    @Name       NVARCHAR(200),
    @Code       NVARCHAR(10),
    @RegionId   INT,
    @CreatedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO lookup.Branches (Name, Code, RegionId, CreatedBy)
        VALUES (@Name, @Code, @RegionId, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_UpdateBranch', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_UpdateBranch;
GO

CREATE PROCEDURE lookup.usp_UpdateBranch
    @Id          INT,
    @Name        NVARCHAR(200),
    @Code        NVARCHAR(10),
    @RegionId    INT,
    @ModifiedBy  NVARCHAR(256),
    @IsUpdated   BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Branches
        SET Name       = @Name,
            Code       = @Code,
            RegionId   = @RegionId,
            ModifiedBy = @ModifiedBy,
            ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_DeleteBranch', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_DeleteBranch;
GO

CREATE PROCEDURE lookup.usp_DeleteBranch
    @Id          INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Branches
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== lookup.Designations ==========

IF OBJECT_ID('lookup.usp_InsertDesignation', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_InsertDesignation;
GO

CREATE PROCEDURE lookup.usp_InsertDesignation
    @Code       NVARCHAR(50),
    @Name       NVARCHAR(200),
    @CreatedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO lookup.Designations (Code, Name, CreatedBy)
        VALUES (@Code, @Name, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_UpdateDesignation', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_UpdateDesignation;
GO

CREATE PROCEDURE lookup.usp_UpdateDesignation
    @Id          INT,
    @Code        NVARCHAR(50),
    @Name        NVARCHAR(200),
    @ModifiedBy  NVARCHAR(256),
    @IsUpdated   BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Designations
        SET Code       = @Code,
            Name       = @Name,
            ModifiedBy = @ModifiedBy,
            ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_DeleteDesignation', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_DeleteDesignation;
GO

CREATE PROCEDURE lookup.usp_DeleteDesignation
    @Id          INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Designations
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== lookup.WorkingDesignations ==========

IF OBJECT_ID('lookup.usp_InsertWorkingDesignation', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_InsertWorkingDesignation;
GO

CREATE PROCEDURE lookup.usp_InsertWorkingDesignation
    @Name       NVARCHAR(200),
    @CreatedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO lookup.WorkingDesignations (Name, CreatedBy)
        VALUES (@Name, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_UpdateWorkingDesignation', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_UpdateWorkingDesignation;
GO

CREATE PROCEDURE lookup.usp_UpdateWorkingDesignation
    @Id          INT,
    @Name        NVARCHAR(200),
    @ModifiedBy  NVARCHAR(256),
    @IsUpdated   BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.WorkingDesignations
        SET Name       = @Name,
            ModifiedBy = @ModifiedBy,
            ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_DeleteWorkingDesignation', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_DeleteWorkingDesignation;
GO

CREATE PROCEDURE lookup.usp_DeleteWorkingDesignation
    @Id          INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.WorkingDesignations
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== lookup.Countries ==========

IF OBJECT_ID('lookup.usp_GetCountries', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_GetCountries;
GO

CREATE PROCEDURE lookup.usp_GetCountries
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Code, Name
        FROM lookup.Countries
        WHERE IsDeleted = 0
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_InsertCountry', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_InsertCountry;
GO

CREATE PROCEDURE lookup.usp_InsertCountry
    @Code       NVARCHAR(3),
    @Name       NVARCHAR(200),
    @CreatedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO lookup.Countries (Code, Name, CreatedBy)
        VALUES (@Code, @Name, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_UpdateCountry', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_UpdateCountry;
GO

CREATE PROCEDURE lookup.usp_UpdateCountry
    @Id          INT,
    @Code        NVARCHAR(3),
    @Name        NVARCHAR(200),
    @ModifiedBy  NVARCHAR(256),
    @IsUpdated   BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Countries
        SET Code       = @Code,
            Name       = @Name,
            ModifiedBy = @ModifiedBy,
            ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_DeleteCountry', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_DeleteCountry;
GO

CREATE PROCEDURE lookup.usp_DeleteCountry
    @Id          INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Countries
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== lookup.Cities ==========

IF OBJECT_ID('lookup.usp_InsertCity', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_InsertCity;
GO

CREATE PROCEDURE lookup.usp_InsertCity
    @Name       NVARCHAR(200),
    @CountryId  INT,
    @CreatedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO lookup.Cities (Name, CountryId, CreatedBy)
        VALUES (@Name, @CountryId, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_UpdateCity', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_UpdateCity;
GO

CREATE PROCEDURE lookup.usp_UpdateCity
    @Id          INT,
    @Name        NVARCHAR(200),
    @CountryId   INT,
    @ModifiedBy  NVARCHAR(256),
    @IsUpdated   BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Cities
        SET Name       = @Name,
            CountryId  = @CountryId,
            ModifiedBy = @ModifiedBy,
            ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_DeleteCity', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_DeleteCity;
GO

CREATE PROCEDURE lookup.usp_DeleteCity
    @Id          INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.Cities
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== lookup.StatusCodes ==========

IF OBJECT_ID('lookup.usp_GetAllStatusCodes', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_GetAllStatusCodes;
GO

CREATE PROCEDURE lookup.usp_GetAllStatusCodes
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Category, Code, Name, SortOrder
        FROM lookup.StatusCodes
        WHERE IsDeleted = 0
        ORDER BY Category, SortOrder;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_InsertStatusCode', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_InsertStatusCode;
GO

CREATE PROCEDURE lookup.usp_InsertStatusCode
    @Category   NVARCHAR(50),
    @Code       NVARCHAR(50),
    @Name       NVARCHAR(150),
    @SortOrder  INT,
    @CreatedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO lookup.StatusCodes (Category, Code, Name, SortOrder, CreatedBy)
        VALUES (@Category, @Code, @Name, @SortOrder, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_UpdateStatusCode', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_UpdateStatusCode;
GO

CREATE PROCEDURE lookup.usp_UpdateStatusCode
    @Id          INT,
    @Category    NVARCHAR(50),
    @Code        NVARCHAR(50),
    @Name        NVARCHAR(150),
    @SortOrder   INT,
    @ModifiedBy  NVARCHAR(256),
    @IsUpdated   BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.StatusCodes
        SET Category   = @Category,
            Code        = @Code,
            Name        = @Name,
            SortOrder   = @SortOrder,
            ModifiedBy  = @ModifiedBy,
            ModifiedAt  = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_DeleteStatusCode', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_DeleteStatusCode;
GO

CREATE PROCEDURE lookup.usp_DeleteStatusCode
    @Id          INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.StatusCodes
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== lookup.UnitsOfMeasure ==========

IF OBJECT_ID('lookup.usp_InsertUnitOfMeasure', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_InsertUnitOfMeasure;
GO

CREATE PROCEDURE lookup.usp_InsertUnitOfMeasure
    @Code       NVARCHAR(20),
    @Name       NVARCHAR(100),
    @CreatedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO lookup.UnitsOfMeasure (Code, Name, CreatedBy)
        VALUES (@Code, @Name, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_UpdateUnitOfMeasure', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_UpdateUnitOfMeasure;
GO

CREATE PROCEDURE lookup.usp_UpdateUnitOfMeasure
    @Id          INT,
    @Code        NVARCHAR(20),
    @Name        NVARCHAR(100),
    @ModifiedBy  NVARCHAR(256),
    @IsUpdated   BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.UnitsOfMeasure
        SET Code       = @Code,
            Name       = @Name,
            ModifiedBy = @ModifiedBy,
            ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('lookup.usp_DeleteUnitOfMeasure', 'P') IS NOT NULL
    DROP PROCEDURE lookup.usp_DeleteUnitOfMeasure;
GO

CREATE PROCEDURE lookup.usp_DeleteUnitOfMeasure
    @Id          INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE lookup.UnitsOfMeasure
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
