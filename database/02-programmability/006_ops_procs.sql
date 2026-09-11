/*
  Purpose:      Operations domain procedures - route lookup, trip listing
                with filters (heavy read path), trip detail/insert, and
                trip status transitions (writes TripStatusHistory too).
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 008_ops_routes_trips_shipments_schema.sql
*/
SET NOCOUNT ON;
GO

IF OBJECT_ID('ops.usp_GetRoutes', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetRoutes;
GO

CREATE PROCEDURE ops.usp_GetRoutes
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            r.Id, r.Name, r.OriginCityId, oc.Name AS OriginCityName,
            r.DestinationCityId, dc.Name AS DestinationCityName, r.DistanceKm
        FROM ops.Routes r
        INNER JOIN lookup.Cities oc ON oc.Id = r.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = r.DestinationCityId
        WHERE r.IsDeleted = 0
        ORDER BY r.Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/*
  Heavy read path: trip listing with filters. Every filter is optional so
  the UI's data grid can call this with whatever subset the user picked.
*/
IF OBJECT_ID('ops.usp_GetTrips', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTrips;
GO

CREATE PROCEDURE ops.usp_GetTrips
    @FromDate   DATETIME2(3) = NULL,
    @ToDate     DATETIME2(3) = NULL,
    @StatusId   INT = NULL,
    @VehicleId  INT = NULL,
    @DriverId   INT = NULL,
    @RouteId    INT = NULL,
    @PageNumber INT = 1,
    @PageSize   INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            t.Id, t.RouteId, r.Name AS RouteName,
            t.VehicleId, v.RegistrationNo,
            t.DriverId, d.FullName AS DriverName,
            t.ScheduledDeparture, t.ScheduledArrival, t.ActualDeparture, t.ActualArrival,
            t.StatusId, sc.Name AS StatusName,
            COUNT(*) OVER() AS TotalCount
        FROM ops.Trips t
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        INNER JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        INNER JOIN fleet.Drivers d ON d.Id = t.DriverId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
        WHERE t.IsDeleted = 0
          AND (@FromDate IS NULL OR t.ScheduledDeparture >= @FromDate)
          AND (@ToDate IS NULL OR t.ScheduledDeparture <= @ToDate)
          AND (@StatusId IS NULL OR t.StatusId = @StatusId)
          AND (@VehicleId IS NULL OR t.VehicleId = @VehicleId)
          AND (@DriverId IS NULL OR t.DriverId = @DriverId)
          AND (@RouteId IS NULL OR t.RouteId = @RouteId)
        ORDER BY t.ScheduledDeparture DESC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_GetTripById', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripById;
GO

CREATE PROCEDURE ops.usp_GetTripById
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            t.Id, t.RouteId, r.Name AS RouteName,
            t.VehicleId, v.RegistrationNo,
            t.DriverId, d.FullName AS DriverName,
            t.ScheduledDeparture, t.ScheduledArrival, t.ActualDeparture, t.ActualArrival,
            t.StatusId, sc.Name AS StatusName
        FROM ops.Trips t
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        INNER JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        INNER JOIN fleet.Drivers d ON d.Id = t.DriverId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
        WHERE t.Id = @TripId AND t.IsDeleted = 0;

        SELECT h.Id, h.StatusId, sc.Name AS StatusName, h.ChangedAt, h.Notes
        FROM ops.TripStatusHistory h
        INNER JOIN lookup.StatusCodes sc ON sc.Id = h.StatusId
        WHERE h.TripId = @TripId
        ORDER BY h.ChangedAt;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertTrip', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertTrip;
GO

CREATE PROCEDURE ops.usp_InsertTrip
    @RouteId             INT,
    @VehicleId           INT,
    @DriverId            INT,
    @ScheduledDeparture  DATETIME2(3),
    @ScheduledArrival    DATETIME2(3),
    @StatusId            INT,
    @CreatedBy           NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO ops.Trips
            (RouteId, VehicleId, DriverId, ScheduledDeparture, ScheduledArrival, StatusId, CreatedBy)
        VALUES
            (@RouteId, @VehicleId, @DriverId, @ScheduledDeparture, @ScheduledArrival, @StatusId, @CreatedBy);

        DECLARE @NewTripId INT = SCOPE_IDENTITY();

        INSERT INTO ops.TripStatusHistory (TripId, StatusId, Notes, CreatedBy)
        VALUES (@NewTripId, @StatusId, 'Trip created', @CreatedBy);

        COMMIT TRANSACTION;

        SELECT @NewTripId AS TripId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_UpdateTripStatus', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpdateTripStatus;
GO

CREATE PROCEDURE ops.usp_UpdateTripStatus
    @TripId     INT,
    @StatusId   INT,
    @Notes      NVARCHAR(500) = NULL,
    @ChangedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE ops.Trips
        SET StatusId   = @StatusId,
            ModifiedBy = @ChangedBy,
            ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @TripId AND IsDeleted = 0;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50001, 'Trip not found', 1;
        END

        INSERT INTO ops.TripStatusHistory (TripId, StatusId, Notes, CreatedBy)
        VALUES (@TripId, @StatusId, @Notes, @ChangedBy);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
