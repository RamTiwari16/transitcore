/*
  Purpose:      GetById + Update procedures for the entities that only had
                Create/List before - Drivers, Routes, Trips, Shipments,
                Customers - needed to extend the Angular app's edit-route
                pattern (built first for Vehicles) to the rest of Fleet/Ops/
                Billing. Trip and Shipment updates are header-only (schedule/
                assignment/customer/route fields) - trip status transitions
                stay on usp_UpdateTripStatus, and shipment line items stay
                read-only here, both being separate, larger pieces of work.
                Customer.Code and Vehicle.RegistrationNo are both treated as
                immutable natural keys once created - Customer follows the
                same convention usp_UpdateVehicle already established.
  Author:       TransitCore rebuild
  Date:         2026-09-15
  Dependencies: 01-schema/006_fleet_schema.sql, 007_billing_customers_schema.sql,
                008_ops_routes_trips_shipments_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO

-- ---------- fleet.usp_GetDriverById ----------
IF OBJECT_ID('fleet.usp_GetDriverById', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetDriverById;
GO

CREATE PROCEDURE fleet.usp_GetDriverById
    @DriverId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            d.Id, d.FullName, d.PhoneNo, d.Email, d.DateOfBirth, d.HireDate,
            d.StatusId, sc.Name AS StatusName
        FROM fleet.Drivers d
        INNER JOIN lookup.StatusCodes sc ON sc.Id = d.StatusId
        WHERE d.Id = @DriverId AND d.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------- fleet.usp_UpdateDriver ----------
IF OBJECT_ID('fleet.usp_UpdateDriver', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_UpdateDriver;
GO

CREATE PROCEDURE fleet.usp_UpdateDriver
    @DriverId     INT,
    @FullName     NVARCHAR(200),
    @PhoneNo      NVARCHAR(30)  = NULL,
    @Email        NVARCHAR(256) = NULL,
    @DateOfBirth  DATE          = NULL,
    @HireDate     DATE          = NULL,
    @StatusId     INT,
    @ModifiedBy   NVARCHAR(256),
    @IsUpdated    BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE fleet.Drivers
        SET FullName    = @FullName,
            PhoneNo      = @PhoneNo,
            Email        = @Email,
            DateOfBirth  = @DateOfBirth,
            HireDate     = @HireDate,
            StatusId     = @StatusId,
            ModifiedBy   = @ModifiedBy,
            ModifiedAt   = SYSUTCDATETIME()
        WHERE Id = @DriverId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------- ops.usp_GetRouteById ----------
IF OBJECT_ID('ops.usp_GetRouteById', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetRouteById;
GO

CREATE PROCEDURE ops.usp_GetRouteById
    @RouteId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            r.Id, r.Name,
            r.OriginCityId, oc.Name AS OriginCityName,
            r.DestinationCityId, dc.Name AS DestinationCityName,
            r.DistanceKm
        FROM ops.Routes r
        INNER JOIN lookup.Cities oc ON oc.Id = r.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = r.DestinationCityId
        WHERE r.Id = @RouteId AND r.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------- ops.usp_UpdateRoute ----------
IF OBJECT_ID('ops.usp_UpdateRoute', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpdateRoute;
GO

CREATE PROCEDURE ops.usp_UpdateRoute
    @RouteId            INT,
    @Name                NVARCHAR(200),
    @OriginCityId        INT,
    @DestinationCityId   INT,
    @DistanceKm          DECIMAL(18,2) = NULL,
    @ModifiedBy          NVARCHAR(256),
    @IsUpdated           BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.Routes
        SET Name               = @Name,
            OriginCityId       = @OriginCityId,
            DestinationCityId  = @DestinationCityId,
            DistanceKm         = @DistanceKm,
            ModifiedBy         = @ModifiedBy,
            ModifiedAt         = SYSUTCDATETIME()
        WHERE Id = @RouteId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------- ops.usp_UpdateTrip ----------
-- Header fields only (route/vehicle/driver/schedule/status) - actual
-- departure/arrival timestamps are set by the dispatch workflow, not this
-- form, and status transitions have their own audited proc
-- (usp_UpdateTripStatus) rather than being silently overwritten here.
IF OBJECT_ID('ops.usp_UpdateTrip', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpdateTrip;
GO

CREATE PROCEDURE ops.usp_UpdateTrip
    @TripId               INT,
    @RouteId               INT,
    @VehicleId             INT,
    @DriverId              INT,
    @ScheduledDeparture    DATETIME2(3),
    @ScheduledArrival      DATETIME2(3),
    @ModifiedBy            NVARCHAR(256),
    @IsUpdated             BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.Trips
        SET RouteId              = @RouteId,
            VehicleId             = @VehicleId,
            DriverId              = @DriverId,
            ScheduledDeparture    = @ScheduledDeparture,
            ScheduledArrival      = @ScheduledArrival,
            ModifiedBy            = @ModifiedBy,
            ModifiedAt            = SYSUTCDATETIME()
        WHERE Id = @TripId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------- ops.usp_UpdateShipment ----------
-- Header fields only - line items (ops.ShipmentItems, inserted via TVP in
-- usp_InsertShipment) are not editable through this proc; they still round-
-- trip read-only through usp_GetShipmentById.
IF OBJECT_ID('ops.usp_UpdateShipment', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpdateShipment;
GO

CREATE PROCEDURE ops.usp_UpdateShipment
    @ShipmentId          INT,
    @CustomerId           INT,
    @OriginCityId         INT,
    @DestinationCityId    INT,
    @StatusId             INT,
    @ShipmentDate         DATE,
    @ModifiedBy           NVARCHAR(256),
    @IsUpdated            BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.Shipments
        SET CustomerId          = @CustomerId,
            OriginCityId         = @OriginCityId,
            DestinationCityId    = @DestinationCityId,
            StatusId             = @StatusId,
            ShipmentDate         = @ShipmentDate,
            ModifiedBy           = @ModifiedBy,
            ModifiedAt           = SYSUTCDATETIME()
        WHERE Id = @ShipmentId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------- billing.usp_GetCustomerById ----------
IF OBJECT_ID('billing.usp_GetCustomerById', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetCustomerById;
GO

CREATE PROCEDURE billing.usp_GetCustomerById
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Code, Name, IsActive
        FROM billing.Customers
        WHERE Id = @CustomerId AND IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ---------- billing.usp_UpdateCustomer ----------
-- Code is the natural business key (UNIQUE constraint) and, like Vehicle's
-- RegistrationNo, is intentionally immutable once created - not accepted
-- here at all, so there's no accidental way to change it via this proc.
IF OBJECT_ID('billing.usp_UpdateCustomer', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_UpdateCustomer;
GO

CREATE PROCEDURE billing.usp_UpdateCustomer
    @CustomerId  INT,
    @Name         NVARCHAR(200),
    @IsActive     BIT,
    @ModifiedBy   NVARCHAR(256),
    @IsUpdated    BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE billing.Customers
        SET Name        = @Name,
            IsActive     = @IsActive,
            ModifiedBy   = @ModifiedBy,
            ModifiedAt   = SYSUTCDATETIME()
        WHERE Id = @CustomerId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
