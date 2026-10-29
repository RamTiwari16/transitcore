/*
  Purpose:      Phase 2 (F3) programmability. Regenerates the Vehicle/
                VehicleType read+write procs for CapacityCbm, regenerates
                ops.ShipmentItemType (TVP - can't be ALTERed, only dropped
                and recreated) and ops.usp_InsertShipment/usp_GetShipmentById
                for per-item VolumeCbm, extends ops.usp_GetTripCapacityCheck
                for volume, and adds the ops.TripStopShipments read/insert/
                delete procs (load-before-unload + exactly-once validation
                lives in the insert proc, not just the table's own
                constraints - see its header comment).
  Author:       TransitCore rebuild
  Date:         2026-09-28
  Dependencies: 01-schema/016_capacity_volume_trip_stop_shipments_schema.sql
*/
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== fleet.VehicleTypes / fleet.Vehicles: CapacityCbm ==========

IF OBJECT_ID('fleet.usp_GetVehicleTypes', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetVehicleTypes;
GO

CREATE PROCEDURE fleet.usp_GetVehicleTypes
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Name, Description, CapacityKg, CapacityCbm
        FROM fleet.VehicleTypes
        WHERE IsDeleted = 0
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_GetVehicles', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetVehicles;
GO

CREATE PROCEDURE fleet.usp_GetVehicles
    @StatusId      INT = NULL,
    @VehicleTypeId INT = NULL,
    @PageNumber    INT = 1,
    @PageSize      INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            v.Id, v.RegistrationNo, v.VehicleTypeId, vt.Name AS VehicleTypeName,
            v.Make, v.Model, v.ManufactureYear, v.CapacityKg, v.CapacityCbm,
            v.StatusId, sc.Name AS StatusName,
            COUNT(*) OVER() AS TotalCount
        FROM fleet.Vehicles v
        INNER JOIN fleet.VehicleTypes vt ON vt.Id = v.VehicleTypeId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = v.StatusId
        WHERE v.IsDeleted = 0
          AND (@StatusId IS NULL OR v.StatusId = @StatusId)
          AND (@VehicleTypeId IS NULL OR v.VehicleTypeId = @VehicleTypeId)
        ORDER BY v.RegistrationNo
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_GetVehicleById', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetVehicleById;
GO

CREATE PROCEDURE fleet.usp_GetVehicleById
    @VehicleId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            v.Id, v.RegistrationNo, v.VehicleTypeId, vt.Name AS VehicleTypeName,
            v.Make, v.Model, v.ManufactureYear, v.CapacityKg, v.CapacityCbm,
            v.StatusId, sc.Name AS StatusName, v.CreatedAt, v.CreatedBy
        FROM fleet.Vehicles v
        INNER JOIN fleet.VehicleTypes vt ON vt.Id = v.VehicleTypeId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = v.StatusId
        WHERE v.Id = @VehicleId AND v.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- @CapacityCbm defaults to 0 (not required) rather than the plain required
-- @CapacityKg above it - staff filling in a vehicle today don't have a
-- volume figure at hand yet in most cases, and 0 is a safe "not specified"
-- placeholder consistent with the column's own DB-level default.
IF OBJECT_ID('fleet.usp_InsertVehicle', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_InsertVehicle;
GO

CREATE PROCEDURE fleet.usp_InsertVehicle
    @RegistrationNo   NVARCHAR(30),
    @VehicleTypeId    INT,
    @Make             NVARCHAR(100) = NULL,
    @Model            NVARCHAR(100) = NULL,
    @ManufactureYear  INT = NULL,
    @CapacityKg       DECIMAL(18,2),
    @CapacityCbm      DECIMAL(18,2) = 0,
    @StatusId         INT,
    @CreatedBy        NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO fleet.Vehicles
            (RegistrationNo, VehicleTypeId, Make, Model, ManufactureYear, CapacityKg, CapacityCbm, StatusId, CreatedBy)
        VALUES
            (@RegistrationNo, @VehicleTypeId, @Make, @Model, @ManufactureYear, @CapacityKg, @CapacityCbm, @StatusId, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS VehicleId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_UpdateVehicle', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_UpdateVehicle;
GO

CREATE PROCEDURE fleet.usp_UpdateVehicle
    @VehicleId        INT,
    @VehicleTypeId    INT,
    @Make             NVARCHAR(100) = NULL,
    @Model            NVARCHAR(100) = NULL,
    @ManufactureYear  INT = NULL,
    @CapacityKg       DECIMAL(18,2),
    @CapacityCbm      DECIMAL(18,2) = 0,
    @StatusId         INT,
    @ModifiedBy       NVARCHAR(256),
    @IsUpdated        BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE fleet.Vehicles
        SET VehicleTypeId   = @VehicleTypeId,
            Make             = @Make,
            Model            = @Model,
            ManufactureYear  = @ManufactureYear,
            CapacityKg       = @CapacityKg,
            CapacityCbm      = @CapacityCbm,
            StatusId         = @StatusId,
            ModifiedBy       = @ModifiedBy,
            ModifiedAt       = SYSUTCDATETIME()
        WHERE Id = @VehicleId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.ShipmentItemType (TVP): VolumeCbm ==========
-- Table types can't be ALTERed - the proc(s) that reference it must be
-- dropped first, then the type dropped and recreated, then the proc(s)
-- recreated. usp_InsertShipment is the only live proc using this type
-- (confirmed by checking every file that references ops.ShipmentItemType).

IF OBJECT_ID('ops.usp_InsertShipment', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertShipment;
GO

IF EXISTS (SELECT 1 FROM sys.types WHERE name = 'ShipmentItemType' AND schema_id = SCHEMA_ID('ops'))
    DROP TYPE ops.ShipmentItemType;
GO

CREATE TYPE ops.ShipmentItemType AS TABLE
(
    Description     NVARCHAR(300) NOT NULL,
    Quantity        DECIMAL(18,2) NOT NULL,
    UnitOfMeasureId INT           NOT NULL,
    WeightKg        DECIMAL(18,2) NULL,
    VolumeCbm       DECIMAL(18,2) NULL
);
GO

CREATE PROCEDURE ops.usp_InsertShipment
    @CustomerId           INT,
    @OriginCityId         INT,
    @DestinationCityId    INT,
    @StatusId             INT,
    @ShipmentDate         DATE,
    @FreightPaymentTypeId INT,
    @BranchId             INT,
    @FinancialYearCode    CHAR(4),
    @TripId               INT = NULL,
    @ConsignorCustomerId  INT = NULL,
    @ConsignorName        NVARCHAR(200) = NULL,
    @ConsignorAddress     NVARCHAR(300) = NULL,
    @ConsignorPhone       NVARCHAR(30) = NULL,
    @ConsigneeCustomerId  INT = NULL,
    @ConsigneeName        NVARCHAR(200) = NULL,
    @ConsigneeAddress     NVARCHAR(300) = NULL,
    @ConsigneePhone       NVARCHAR(30) = NULL,
    @CreatedBy            NVARCHAR(256),
    @Items                ops.ShipmentItemType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO ops.Shipments
            (TripId, CustomerId, OriginCityId, DestinationCityId, StatusId, ShipmentDate,
             FreightPaymentTypeId, ConsignorCustomerId, ConsignorName, ConsignorAddress, ConsignorPhone,
             ConsigneeCustomerId, ConsigneeName, ConsigneeAddress, ConsigneePhone, CreatedBy)
        VALUES
            (@TripId, @CustomerId, @OriginCityId, @DestinationCityId, @StatusId, @ShipmentDate,
             @FreightPaymentTypeId, @ConsignorCustomerId, @ConsignorName, @ConsignorAddress, @ConsignorPhone,
             @ConsigneeCustomerId, @ConsigneeName, @ConsigneeAddress, @ConsigneePhone, @CreatedBy);

        DECLARE @NewShipmentId INT = SCOPE_IDENTITY();

        UPDATE ops.Shipments
        SET TrackingNo = 'TRK' + RIGHT('000000' + CAST(@NewShipmentId AS VARCHAR(6)), 6)
        WHERE Id = @NewShipmentId;

        INSERT INTO ops.ShipmentItems (ShipmentId, Description, Quantity, UnitOfMeasureId, WeightKg, VolumeCbm, CreatedBy)
        SELECT @NewShipmentId, Description, Quantity, UnitOfMeasureId, WeightKg, VolumeCbm, @CreatedBy
        FROM @Items;

        DECLARE @BranchCode NVARCHAR(10);
        SELECT @BranchCode = Code FROM lookup.Branches WHERE Id = @BranchId;

        IF NOT EXISTS (
            SELECT 1 FROM ops.ConsignmentNoteSequences WITH (UPDLOCK, HOLDLOCK)
            WHERE BranchId = @BranchId AND FinancialYearCode = @FinancialYearCode
        )
            INSERT INTO ops.ConsignmentNoteSequences (BranchId, FinancialYearCode, LastSequence)
            VALUES (@BranchId, @FinancialYearCode, 0);

        DECLARE @NextSeq INT;
        UPDATE ops.ConsignmentNoteSequences WITH (UPDLOCK, HOLDLOCK)
        SET @NextSeq = LastSequence = LastSequence + 1
        WHERE BranchId = @BranchId AND FinancialYearCode = @FinancialYearCode;

        DECLARE @FormatTemplate NVARCHAR(100), @SequencePadding INT;
        SELECT TOP (1) @FormatTemplate = FormatTemplate, @SequencePadding = SequencePadding
        FROM ops.ConsignmentNoteNumberFormats
        WHERE IsDeleted = 0 AND (BranchId = @BranchId OR BranchId IS NULL)
        ORDER BY CASE WHEN BranchId = @BranchId THEN 0 ELSE 1 END;

        DECLARE @CnNumber NVARCHAR(50) = REPLACE(REPLACE(REPLACE(
            @FormatTemplate,
            '{BRANCH}', @BranchCode),
            '{FY}', @FinancialYearCode),
            '{SEQ}', RIGHT(REPLICATE('0', @SequencePadding) + CAST(@NextSeq AS VARCHAR(10)), @SequencePadding));

        DECLARE @BookedStatusId INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Shipment' AND Code = 'BOOKED');

        INSERT INTO ops.ConsignmentNotes (ShipmentId, CnNumber, BranchId, CnDate, StatusId, CreatedBy)
        VALUES (@NewShipmentId, @CnNumber, @BranchId, @ShipmentDate, @BookedStatusId, @CreatedBy);

        COMMIT TRANSACTION;

        SELECT @NewShipmentId AS ShipmentId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ========== ops.usp_GetShipmentById: VolumeCbm on items ==========

IF OBJECT_ID('ops.usp_GetShipmentById', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetShipmentById;
GO

CREATE PROCEDURE ops.usp_GetShipmentById
    @ShipmentId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            s.Id, s.TripId, s.CustomerId, c.Name AS CustomerName,
            s.OriginCityId, oc.Name AS OriginCityName,
            s.DestinationCityId, dc.Name AS DestinationCityName,
            s.StatusId, sc.Name AS StatusName, s.ShipmentDate, s.TrackingNo,
            s.FreightPaymentTypeId, fpt.Name AS FreightPaymentTypeName,
            s.ConsignorCustomerId, cc.Name AS ConsignorCustomerName, s.ConsignorName, s.ConsignorAddress, s.ConsignorPhone,
            s.ConsigneeCustomerId, ce.Name AS ConsigneeCustomerName, s.ConsigneeName, s.ConsigneeAddress, s.ConsigneePhone,
            cn.CnNumber
        FROM ops.Shipments s
        INNER JOIN billing.Customers c ON c.Id = s.CustomerId
        INNER JOIN lookup.Cities oc ON oc.Id = s.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = s.DestinationCityId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = s.StatusId
        INNER JOIN lookup.StatusCodes fpt ON fpt.Id = s.FreightPaymentTypeId
        LEFT JOIN billing.Customers cc ON cc.Id = s.ConsignorCustomerId
        LEFT JOIN billing.Customers ce ON ce.Id = s.ConsigneeCustomerId
        LEFT JOIN ops.ConsignmentNotes cn ON cn.ShipmentId = s.Id
        WHERE s.Id = @ShipmentId AND s.IsDeleted = 0;

        SELECT si.Id, si.Description, si.Quantity, si.UnitOfMeasureId, uom.Code AS UnitOfMeasureCode, si.WeightKg, si.VolumeCbm
        FROM ops.ShipmentItems si
        INNER JOIN lookup.UnitsOfMeasure uom ON uom.Id = si.UnitOfMeasureId
        WHERE si.ShipmentId = @ShipmentId AND si.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.usp_GetTripCapacityCheck: weight AND volume ==========

IF OBJECT_ID('ops.usp_GetTripCapacityCheck', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripCapacityCheck;
GO

CREATE PROCEDURE ops.usp_GetTripCapacityCheck
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            @TripId AS TripId,
            v.CapacityKg AS VehicleCapacityKg,
            v.CapacityCbm AS VehicleCapacityCbm,
            ISNULL((
                SELECT SUM(si.WeightKg)
                FROM ops.Shipments sh
                INNER JOIN ops.ShipmentItems si ON si.ShipmentId = sh.Id AND si.IsDeleted = 0
                WHERE sh.TripId = @TripId AND sh.IsDeleted = 0
            ), 0) AS AssignedWeightKg,
            ISNULL((
                SELECT SUM(si.VolumeCbm)
                FROM ops.Shipments sh
                INNER JOIN ops.ShipmentItems si ON si.ShipmentId = sh.Id AND si.IsDeleted = 0
                WHERE sh.TripId = @TripId AND sh.IsDeleted = 0
            ), 0) AS AssignedVolumeCbm
        FROM ops.Trips t
        INNER JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        WHERE t.Id = @TripId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.TripStopShipments: read / insert / delete ==========
-- Per-stop sort key used both here and in the insert proc's ordering
-- validation: Origin always first (rank 0), IntermediateStop ordered by
-- its RouteStops.StopOrder (rank 1, tiebreak on StopOrder), Destination
-- always last (rank 2) - regardless of what actual StopOrder numbers a
-- route's intermediate stops use.

IF OBJECT_ID('ops.usp_GetTripStopShipments', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripStopShipments;
GO

CREATE PROCEDURE ops.usp_GetTripStopShipments
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            tss.Id, tss.TripId, tss.ShipmentId, sh.TrackingNo, sh.CustomerId, c.Name AS CustomerName,
            tss.Action, tss.StopType, tss.RouteStopId,
            CASE tss.StopType
                WHEN 'Origin' THEN oc.Name
                WHEN 'Destination' THEN dc.Name
                ELSE rsc.Name
            END AS StopCityName,
            CASE tss.StopType WHEN 'Origin' THEN 0 WHEN 'IntermediateStop' THEN 1 ELSE 2 END * 100000
                + ISNULL(rs.StopOrder, 0) AS SortKey,
            tss.CreatedAt, tss.CreatedBy
        FROM ops.TripStopShipments tss
        INNER JOIN ops.Shipments sh ON sh.Id = tss.ShipmentId
        INNER JOIN billing.Customers c ON c.Id = sh.CustomerId
        INNER JOIN ops.Trips t ON t.Id = tss.TripId
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        INNER JOIN lookup.Cities oc ON oc.Id = r.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = r.DestinationCityId
        LEFT JOIN ops.RouteStops rs ON rs.Id = tss.RouteStopId
        LEFT JOIN lookup.Cities rsc ON rsc.Id = rs.CityId
        WHERE tss.TripId = @TripId AND tss.IsDeleted = 0
        ORDER BY SortKey, tss.Action;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertTripStopShipment', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertTripStopShipment;
GO

CREATE PROCEDURE ops.usp_InsertTripStopShipment
    @TripId        INT,
    @ShipmentId    INT,
    @Action        NVARCHAR(10),
    @StopType      NVARCHAR(20),
    @RouteStopId   INT = NULL,
    @CreatedBy     NVARCHAR(256),
    @Success       BIT OUTPUT,
    @ErrorMessage  NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @Success = 0;
        SET @ErrorMessage = NULL;

        DECLARE @RouteId INT;
        SELECT @RouteId = RouteId FROM ops.Trips WHERE Id = @TripId AND IsDeleted = 0;
        IF @RouteId IS NULL
        BEGIN
            SET @ErrorMessage = 'Trip not found';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM ops.Shipments WHERE Id = @ShipmentId AND TripId = @TripId AND IsDeleted = 0)
        BEGIN
            SET @ErrorMessage = 'Shipment is not assigned to this trip';
            RETURN;
        END

        IF @StopType = 'IntermediateStop'
        BEGIN
            IF @RouteStopId IS NULL OR NOT EXISTS (
                SELECT 1 FROM ops.RouteStops WHERE Id = @RouteStopId AND RouteId = @RouteId AND IsDeleted = 0
            )
            BEGIN
                SET @ErrorMessage = 'Stop does not belong to this trip''s route';
                RETURN;
            END
        END
        ELSE IF @RouteStopId IS NOT NULL
        BEGIN
            SET @ErrorMessage = 'Origin/Destination events cannot reference a route stop';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM ops.TripStopShipments WHERE TripId = @TripId AND ShipmentId = @ShipmentId AND Action = @Action AND IsDeleted = 0)
        BEGIN
            SET @ErrorMessage = CONCAT('This shipment already has a ', LOWER(@Action), ' event on this trip');
            RETURN;
        END

        DECLARE @NewSortKey INT = (CASE @StopType WHEN 'Origin' THEN 0 WHEN 'IntermediateStop' THEN 1 ELSE 2 END) * 100000
            + ISNULL((SELECT StopOrder FROM ops.RouteStops WHERE Id = @RouteStopId), 0);

        DECLARE @OtherAction NVARCHAR(10) = CASE @Action WHEN 'Load' THEN 'Unload' ELSE 'Load' END;
        DECLARE @OtherSortKey INT;

        SELECT @OtherSortKey =
            (CASE tss.StopType WHEN 'Origin' THEN 0 WHEN 'IntermediateStop' THEN 1 ELSE 2 END) * 100000
                + ISNULL(rs.StopOrder, 0)
        FROM ops.TripStopShipments tss
        LEFT JOIN ops.RouteStops rs ON rs.Id = tss.RouteStopId
        WHERE tss.TripId = @TripId AND tss.ShipmentId = @ShipmentId AND tss.Action = @OtherAction AND tss.IsDeleted = 0;

        IF @Action = 'Unload' AND @OtherSortKey IS NULL
        BEGIN
            SET @ErrorMessage = 'Shipment must be loaded before it can be unloaded on this trip';
            RETURN;
        END

        IF @OtherSortKey IS NOT NULL
        BEGIN
            DECLARE @LoadSortKey INT = CASE WHEN @Action = 'Load' THEN @NewSortKey ELSE @OtherSortKey END;
            DECLARE @UnloadSortKey INT = CASE WHEN @Action = 'Unload' THEN @NewSortKey ELSE @OtherSortKey END;

            IF @LoadSortKey >= @UnloadSortKey
            BEGIN
                SET @ErrorMessage = 'Load stop must come before the unload stop';
                RETURN;
            END
        END

        INSERT INTO ops.TripStopShipments (TripId, ShipmentId, Action, StopType, RouteStopId, CreatedBy)
        VALUES (@TripId, @ShipmentId, @Action, @StopType, @RouteStopId, @CreatedBy);

        SET @Success = 1;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_DeleteTripStopShipment', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_DeleteTripStopShipment;
GO

CREATE PROCEDURE ops.usp_DeleteTripStopShipment
    @Id           INT,
    @ModifiedBy   NVARCHAR(256),
    @Success      BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.TripStopShipments
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
