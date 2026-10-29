/*
  Purpose:      Phase 3 (Ops depth) - regenerates usp_GetShipments and
                usp_GetShipmentById to include the TrackingNo column added in
                012_ops_phase3_schema.sql, so the authenticated list/detail
                screens can show it (separate from the public tracking
                lookup in 017, which is intentionally a different, narrower
                proc for the unauthenticated endpoint).
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 02-programmability/009_ops_shipment_procs.sql,
                01-schema/012_ops_phase3_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
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
            s.StatusId, sc.Name AS StatusName, s.ShipmentDate, s.TrackingNo
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
            s.StatusId, sc.Name AS StatusName, s.ShipmentDate, s.TrackingNo
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
