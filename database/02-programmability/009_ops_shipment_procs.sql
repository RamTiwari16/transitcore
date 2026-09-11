/*
  Purpose:      Shipment listing, detail (with items), and insert (with
                items TVP, explicit transaction).
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 008_ops_routes_trips_shipments_schema.sql, 011_ops_shipment_tvp.sql
*/
SET NOCOUNT ON;
GO

IF OBJECT_ID('ops.usp_GetShipments', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetShipments;
GO

CREATE PROCEDURE ops.usp_GetShipments
    @CustomerId INT = NULL,
    @StatusId   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            s.Id, s.TripId, s.CustomerId, c.Name AS CustomerName,
            s.OriginCityId, oc.Name AS OriginCityName,
            s.DestinationCityId, dc.Name AS DestinationCityName,
            s.StatusId, sc.Name AS StatusName, s.ShipmentDate
        FROM ops.Shipments s
        INNER JOIN billing.Customers c ON c.Id = s.CustomerId
        INNER JOIN lookup.Cities oc ON oc.Id = s.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = s.DestinationCityId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = s.StatusId
        WHERE s.IsDeleted = 0
          AND (@CustomerId IS NULL OR s.CustomerId = @CustomerId)
          AND (@StatusId IS NULL OR s.StatusId = @StatusId)
        ORDER BY s.ShipmentDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

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
            s.StatusId, sc.Name AS StatusName, s.ShipmentDate
        FROM ops.Shipments s
        INNER JOIN billing.Customers c ON c.Id = s.CustomerId
        INNER JOIN lookup.Cities oc ON oc.Id = s.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = s.DestinationCityId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = s.StatusId
        WHERE s.Id = @ShipmentId AND s.IsDeleted = 0;

        SELECT si.Id, si.Description, si.Quantity, si.UnitOfMeasureId, uom.Code AS UnitOfMeasureCode, si.WeightKg
        FROM ops.ShipmentItems si
        INNER JOIN lookup.UnitsOfMeasure uom ON uom.Id = si.UnitOfMeasureId
        WHERE si.ShipmentId = @ShipmentId AND si.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
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
