/*
  Purpose:      Bulk insert + date-range read for VehicleOrderMapping.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 004_ops_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('ops.usp_BulkInsertVehicleOrderMapping', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_BulkInsertVehicleOrderMapping;
GO

CREATE PROCEDURE ops.usp_BulkInsertVehicleOrderMapping
    @Mappings ops.VehicleOrderMappingType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO ops.VehicleOrderMapping (VehicleNo, OrderNo, UploadDate, CreatedByEmail, CreatedBy)
        SELECT VehicleNo, OrderNo, UploadDate, CreatedByEmail, CreatedByEmail
        FROM @Mappings;

        DECLARE @Inserted INT = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT @Inserted AS InsertedCount;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_GetVehicleOrderMappingByDateRange', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetVehicleOrderMappingByDateRange;
GO

CREATE PROCEDURE ops.usp_GetVehicleOrderMappingByDateRange
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, VehicleNo, OrderNo, UploadDate, CreatedByEmail, CreatedAt
        FROM ops.VehicleOrderMapping
        WHERE UploadDate BETWEEN @FromDate AND @ToDate
          AND IsDeleted = 0
        ORDER BY UploadDate DESC, Id DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
