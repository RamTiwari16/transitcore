/*
  Purpose:      Phase 2 (Fleet depth) - CRUD + expiry-alert procs for the
                three vehicle sub-resource tables that already existed in
                006_fleet_schema.sql but had no procs touching them yet:
                VehicleDocuments, MaintenanceRecords, FuelLogs. All three are
                append/delete only (no update) - correcting a bad log entry
                is a delete-and-re-add, not an edit-in-place, which keeps the
                proc surface smaller and matches how these get used in
                practice (a wrong odometer reading isn't "edited", it's
                removed and re-entered correctly).
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 01-schema/006_fleet_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO

-- ========== fleet.VehicleDocuments ==========

IF OBJECT_ID('fleet.usp_GetVehicleDocuments', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetVehicleDocuments;
GO

CREATE PROCEDURE fleet.usp_GetVehicleDocuments
    @VehicleId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, VehicleId, DocumentType, DocumentNo, IssuedDate, ExpiryDate
        FROM fleet.VehicleDocuments
        WHERE VehicleId = @VehicleId AND IsDeleted = 0
        ORDER BY ISNULL(ExpiryDate, '9999-12-31') ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_InsertVehicleDocument', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_InsertVehicleDocument;
GO

CREATE PROCEDURE fleet.usp_InsertVehicleDocument
    @VehicleId     INT,
    @DocumentType  NVARCHAR(100),
    @DocumentNo    NVARCHAR(100) = NULL,
    @IssuedDate    DATE = NULL,
    @ExpiryDate    DATE = NULL,
    @CreatedBy     NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO fleet.VehicleDocuments (VehicleId, DocumentType, DocumentNo, IssuedDate, ExpiryDate, CreatedBy)
        VALUES (@VehicleId, @DocumentType, @DocumentNo, @IssuedDate, @ExpiryDate, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_DeleteVehicleDocument', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_DeleteVehicleDocument;
GO

CREATE PROCEDURE fleet.usp_DeleteVehicleDocument
    @DocumentId  INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE fleet.VehicleDocuments
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @DocumentId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Feeds the Dashboard alerts panel - documents already expired or expiring
-- within @DaysAhead days, across the whole fleet (not scoped to one vehicle).
IF OBJECT_ID('fleet.usp_GetExpiringVehicleDocuments', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetExpiringVehicleDocuments;
GO

CREATE PROCEDURE fleet.usp_GetExpiringVehicleDocuments
    @DaysAhead INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            d.Id, d.VehicleId, v.RegistrationNo, d.DocumentType, d.DocumentNo, d.ExpiryDate
        FROM fleet.VehicleDocuments d
        INNER JOIN fleet.Vehicles v ON v.Id = d.VehicleId
        WHERE d.IsDeleted = 0
          AND d.ExpiryDate IS NOT NULL
          AND d.ExpiryDate <= DATEADD(DAY, @DaysAhead, CAST(SYSUTCDATETIME() AS DATE))
        ORDER BY d.ExpiryDate ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== fleet.MaintenanceRecords ==========

IF OBJECT_ID('fleet.usp_GetMaintenanceRecords', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetMaintenanceRecords;
GO

CREATE PROCEDURE fleet.usp_GetMaintenanceRecords
    @VehicleId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, VehicleId, ServiceDate, Description, Cost, OdometerKm, PerformedBy
        FROM fleet.MaintenanceRecords
        WHERE VehicleId = @VehicleId AND IsDeleted = 0
        ORDER BY ServiceDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_InsertMaintenanceRecord', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_InsertMaintenanceRecord;
GO

CREATE PROCEDURE fleet.usp_InsertMaintenanceRecord
    @VehicleId    INT,
    @ServiceDate  DATE,
    @Description  NVARCHAR(500) = NULL,
    @Cost         DECIMAL(18,2) = 0,
    @OdometerKm   INT = NULL,
    @PerformedBy  NVARCHAR(200) = NULL,
    @CreatedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO fleet.MaintenanceRecords (VehicleId, ServiceDate, Description, Cost, OdometerKm, PerformedBy, CreatedBy)
        VALUES (@VehicleId, @ServiceDate, @Description, @Cost, @OdometerKm, @PerformedBy, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_DeleteMaintenanceRecord', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_DeleteMaintenanceRecord;
GO

CREATE PROCEDURE fleet.usp_DeleteMaintenanceRecord
    @MaintenanceId  INT,
    @ModifiedBy     NVARCHAR(256),
    @Success        BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE fleet.MaintenanceRecords
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @MaintenanceId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== fleet.FuelLogs ==========
-- km/L is deliberately not computed here: it needs the PREVIOUS log's
-- odometer reading, which is a per-row window function over an already
-- small, per-vehicle result set - simpler and just as correct to compute in
-- the API layer once the ordered list is in memory.

IF OBJECT_ID('fleet.usp_GetFuelLogs', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetFuelLogs;
GO

CREATE PROCEDURE fleet.usp_GetFuelLogs
    @VehicleId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, VehicleId, FuelDate, Liters, Cost, OdometerKm
        FROM fleet.FuelLogs
        WHERE VehicleId = @VehicleId AND IsDeleted = 0
        ORDER BY FuelDate ASC, OdometerKm ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_InsertFuelLog', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_InsertFuelLog;
GO

CREATE PROCEDURE fleet.usp_InsertFuelLog
    @VehicleId   INT,
    @FuelDate    DATE,
    @Liters      DECIMAL(18,2),
    @Cost        DECIMAL(18,2),
    @OdometerKm  INT = NULL,
    @CreatedBy   NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO fleet.FuelLogs (VehicleId, FuelDate, Liters, Cost, OdometerKm, CreatedBy)
        VALUES (@VehicleId, @FuelDate, @Liters, @Cost, @OdometerKm, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_DeleteFuelLog', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_DeleteFuelLog;
GO

CREATE PROCEDURE fleet.usp_DeleteFuelLog
    @FuelLogId   INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE fleet.FuelLogs
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @FuelLogId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
