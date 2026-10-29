/*
  Purpose:      Phase 3 (Ops depth) - multi-stop route legs (ops.RouteStops
                already existed unused), a trip capacity check (assigned
                shipment weight vs vehicle capacity), a dispatch conflict
                check (does this driver/vehicle already have an overlapping
                trip), and the public shipment tracking lookup.
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 01-schema/008_ops_routes_trips_shipments_schema.sql,
                01-schema/012_ops_phase3_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO

-- ========== ops.RouteStops ==========

IF OBJECT_ID('ops.usp_GetRouteStops', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetRouteStops;
GO

CREATE PROCEDURE ops.usp_GetRouteStops
    @RouteId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT s.Id, s.RouteId, s.CityId, c.Name AS CityName, s.StopOrder, s.PlannedArrival
        FROM ops.RouteStops s
        INNER JOIN lookup.Cities c ON c.Id = s.CityId
        WHERE s.RouteId = @RouteId AND s.IsDeleted = 0
        ORDER BY s.StopOrder ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertRouteStop', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertRouteStop;
GO

CREATE PROCEDURE ops.usp_InsertRouteStop
    @RouteId         INT,
    @CityId          INT,
    @StopOrder       INT,
    @PlannedArrival  DATETIME2(3) = NULL,
    @CreatedBy       NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.RouteStops (RouteId, CityId, StopOrder, PlannedArrival, CreatedBy)
        VALUES (@RouteId, @CityId, @StopOrder, @PlannedArrival, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_DeleteRouteStop', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_DeleteRouteStop;
GO

CREATE PROCEDURE ops.usp_DeleteRouteStop
    @StopId      INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.RouteStops
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @StopId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Trip capacity check ==========
-- Sums the weight of every shipment item on shipments linked to this trip
-- and compares it to the assigned vehicle's CapacityKg. A soft check (the
-- caller decides whether to warn or block) rather than a DB constraint,
-- since a real dispatcher may have a legitimate reason to override it.

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
            ISNULL((
                SELECT SUM(si.WeightKg)
                FROM ops.Shipments sh
                INNER JOIN ops.ShipmentItems si ON si.ShipmentId = sh.Id AND si.IsDeleted = 0
                WHERE sh.TripId = @TripId AND sh.IsDeleted = 0
            ), 0) AS AssignedWeightKg
        FROM ops.Trips t
        INNER JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        WHERE t.Id = @TripId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Dispatch conflict check ==========
-- Any other non-cancelled trip for the same driver OR vehicle whose
-- scheduled window overlaps the given window (classic interval-overlap
-- test: existing.start < new.end AND existing.end > new.start).
-- @ExcludeTripId lets an edit-in-place check ignore the trip's own row.

IF OBJECT_ID('ops.usp_CheckTripConflicts', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_CheckTripConflicts;
GO

CREATE PROCEDURE ops.usp_CheckTripConflicts
    @DriverId             INT,
    @VehicleId            INT,
    @ScheduledDeparture   DATETIME2(3),
    @ScheduledArrival     DATETIME2(3),
    @ExcludeTripId        INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            t.Id, t.RouteId, r.Name AS RouteName, t.VehicleId, v.RegistrationNo,
            t.DriverId, d.FullName AS DriverName,
            t.ScheduledDeparture, t.ScheduledArrival, t.StatusId, sc.Name AS StatusName,
            CASE WHEN t.DriverId = @DriverId THEN 1 ELSE 0 END AS IsDriverConflict,
            CASE WHEN t.VehicleId = @VehicleId THEN 1 ELSE 0 END AS IsVehicleConflict
        FROM ops.Trips t
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        INNER JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        INNER JOIN fleet.Drivers d ON d.Id = t.DriverId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
        WHERE t.IsDeleted = 0
          AND sc.Name NOT IN ('Cancelled', 'Completed')
          AND (t.DriverId = @DriverId OR t.VehicleId = @VehicleId)
          AND (@ExcludeTripId IS NULL OR t.Id <> @ExcludeTripId)
          AND t.ScheduledDeparture < @ScheduledArrival
          AND t.ScheduledArrival > @ScheduledDeparture
        ORDER BY t.ScheduledDeparture ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Public shipment tracking ==========
-- Deliberately minimal, public-safe columns only - no customer name,
-- pricing, or internal ids beyond the shipment's own tracking number. This
-- backs an unauthenticated endpoint.

IF OBJECT_ID('ops.usp_TrackShipment', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_TrackShipment;
GO

CREATE PROCEDURE ops.usp_TrackShipment
    @TrackingNo NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            sh.TrackingNo, sh.ShipmentDate,
            oc.Name AS OriginCityName, dc.Name AS DestinationCityName,
            sc.Name AS StatusName,
            t.ScheduledDeparture, t.ScheduledArrival, t.ActualDeparture, t.ActualArrival,
            tsc.Name AS TripStatusName
        FROM ops.Shipments sh
        INNER JOIN lookup.Cities oc ON oc.Id = sh.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = sh.DestinationCityId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = sh.StatusId
        LEFT JOIN ops.Trips t ON t.Id = sh.TripId AND t.IsDeleted = 0
        LEFT JOIN lookup.StatusCodes tsc ON tsc.Id = t.StatusId
        WHERE sh.TrackingNo = @TrackingNo AND sh.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
