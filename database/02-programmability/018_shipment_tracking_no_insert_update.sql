/*
  Purpose:      Phase 3 (Ops depth) - regenerates ops.usp_InsertShipment to
                assign a TrackingNo (same TRK+zero-padded-id format as the
                012_ops_phase3_schema.sql backfill for pre-existing rows) on
                every new shipment, so the public tracking page always has
                something to look up.
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 02-programmability/009_ops_shipment_procs.sql,
                01-schema/012_ops_phase3_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('ops.usp_InsertShipment', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertShipment;
GO

CREATE PROCEDURE ops.usp_InsertShipment
    @CustomerId        INT,
    @OriginCityId      INT,
    @DestinationCityId INT,
    @StatusId          INT,
    @ShipmentDate      DATE,
    @TripId            INT = NULL,
    @CreatedBy         NVARCHAR(256),
    @Items             ops.ShipmentItemType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO ops.Shipments
            (TripId, CustomerId, OriginCityId, DestinationCityId, StatusId, ShipmentDate, CreatedBy)
        VALUES
            (@TripId, @CustomerId, @OriginCityId, @DestinationCityId, @StatusId, @ShipmentDate, @CreatedBy);

        DECLARE @NewShipmentId INT = SCOPE_IDENTITY();

        UPDATE ops.Shipments
        SET TrackingNo = 'TRK' + RIGHT('000000' + CAST(@NewShipmentId AS VARCHAR(6)), 6)
        WHERE Id = @NewShipmentId;

        INSERT INTO ops.ShipmentItems (ShipmentId, Description, Quantity, UnitOfMeasureId, WeightKg, CreatedBy)
        SELECT @NewShipmentId, Description, Quantity, UnitOfMeasureId, WeightKg, @CreatedBy
        FROM @Items;

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
