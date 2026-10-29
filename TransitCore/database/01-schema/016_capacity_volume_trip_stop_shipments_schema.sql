/*
  Purpose:      Phase 2 (F3) of the freight-carrier feature set. Adds volume
                capacity (CapacityCbm) alongside the existing weight capacity
                on VehicleTypes and Vehicles, a per-item volume on
                ShipmentItems, and ops.TripStopShipments - which shipment
                loads/unloads at which stop on a trip, including the trip's
                own origin/destination (which have no ops.RouteStops row of
                their own - see StopType below).
  Author:       TransitCore rebuild
  Date:         2026-09-28
  Dependencies: 006_fleet_schema.sql (fleet.VehicleTypes, fleet.Vehicles),
                008_ops_routes_trips_shipments_schema.sql (ops.Trips,
                ops.Shipments, ops.ShipmentItems, ops.RouteStops)

  Design note (matches the approved approach): ops.RouteStops only ever held
  INTERMEDIATE stops - a route's origin/destination live on ops.Routes
  itself, and plenty of routes have zero intermediate stops at all. Rather
  than force every route to carry explicit start/end RouteStops rows
  (invasive - would touch existing route data and the route-stops UI),
  ops.TripStopShipments models a trip's origin and destination as implicit
  stops: StopType is 'Origin' / 'IntermediateStop' / 'Destination', and
  RouteStopId is populated only for the IntermediateStop case. Ordering for
  the "loaded before unloaded" rule sorts Origin first, IntermediateStop by
  RouteStops.StopOrder, Destination last - see
  02-programmability/027_capacity_volume_trip_stop_shipments_procs.sql.
*/
-- Defensive, matching every other file touching ops.RouteStops-adjacent
-- tables in this codebase: filtered indexes elsewhere need
-- QUOTED_IDENTIFIER ON in the same session/batch stream, and this file's
-- ops.TripStopShipments FKs into ops.RouteStops (which has one - see
-- 015_route_stops_active_stop_order.sql).
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== fleet.VehicleTypes / fleet.Vehicles: volume capacity ==========

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('fleet.VehicleTypes') AND name = 'CapacityCbm')
    ALTER TABLE fleet.VehicleTypes ADD CapacityCbm DECIMAL(18,2) NOT NULL CONSTRAINT DF_VehicleTypes_CapacityCbm DEFAULT 0;
GO

-- Backfill for a database where these 8 type rows already exist (the ALTER's
-- own DEFAULT 0 already covers a brand-new database's fresh INSERTs from
-- 03-seed/004_fleet_seed.sql, which also supplies real values directly).
UPDATE fleet.VehicleTypes
SET CapacityCbm = CASE Name
    WHEN 'Small Truck'          THEN 9
    WHEN 'Medium Truck'         THEN 20
    WHEN 'Large Truck'          THEN 35
    WHEN 'Container Truck'      THEN 45
    WHEN 'Trailer'               THEN 55
    WHEN 'Refrigerated Truck'   THEN 18
    WHEN 'Tanker'                THEN 20
    WHEN 'Van'                   THEN 6
    ELSE CapacityCbm
END
WHERE CapacityCbm = 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('fleet.Vehicles') AND name = 'CapacityCbm')
    ALTER TABLE fleet.Vehicles ADD CapacityCbm DECIMAL(18,2) NOT NULL CONSTRAINT DF_Vehicles_CapacityCbm DEFAULT 0;
GO

-- Backfill: inherit the vehicle's type's (now-populated) CapacityCbm, for
-- any vehicle still sitting at the column's own default of 0 - i.e. every
-- pre-existing row (there is no admin/staff-facing way to set this yet, see
-- 027_...procs.sql's comment on usp_InsertVehicle/usp_UpdateVehicle).
UPDATE v
SET v.CapacityCbm = vt.CapacityCbm
FROM fleet.Vehicles v
INNER JOIN fleet.VehicleTypes vt ON vt.Id = v.VehicleTypeId
WHERE v.CapacityCbm = 0;
GO

-- ========== ops.ShipmentItems: per-item volume ==========

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ops.ShipmentItems') AND name = 'VolumeCbm')
    ALTER TABLE ops.ShipmentItems ADD VolumeCbm DECIMAL(18,2) NULL;
GO

-- ========== ops.TripStopShipments: load/unload events ==========

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.TripStopShipments') AND type = 'U')
BEGIN
    CREATE TABLE ops.TripStopShipments
    (
        Id            INT IDENTITY(1,1) NOT NULL,
        TripId        INT               NOT NULL,
        ShipmentId    INT               NOT NULL,
        Action        NVARCHAR(10)      NOT NULL,
        StopType      NVARCHAR(20)      NOT NULL,
        -- Populated only when StopType = 'IntermediateStop' - NULL for the
        -- trip's own Origin/Destination, which have no RouteStops row.
        RouteStopId   INT               NULL,
        CreatedAt     DATETIME2(3)      NOT NULL CONSTRAINT DF_TripStopShipments_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy     NVARCHAR(256)     NULL,
        ModifiedAt    DATETIME2(3)      NULL,
        ModifiedBy    NVARCHAR(256)     NULL,
        IsDeleted     BIT               NOT NULL CONSTRAINT DF_TripStopShipments_IsDeleted DEFAULT 0,
        CONSTRAINT PK_TripStopShipments PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_TripStopShipments_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_TripStopShipments_Shipments FOREIGN KEY (ShipmentId) REFERENCES ops.Shipments (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_TripStopShipments_RouteStops FOREIGN KEY (RouteStopId) REFERENCES ops.RouteStops (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_TripStopShipments_Action CHECK (Action IN ('Load', 'Unload')),
        CONSTRAINT CK_TripStopShipments_StopType CHECK (StopType IN ('Origin', 'IntermediateStop', 'Destination')),
        CONSTRAINT CK_TripStopShipments_RouteStopConsistency CHECK (
            (StopType = 'IntermediateStop' AND RouteStopId IS NOT NULL) OR
            (StopType <> 'IntermediateStop' AND RouteStopId IS NULL)
        ),
        -- "unloaded exactly once" (and "loaded exactly once") enforced here
        -- directly, not just in the insert proc's validation.
        CONSTRAINT UQ_TripStopShipments_OnePerAction UNIQUE (TripId, ShipmentId, Action)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TripStopShipments_TripId' AND object_id = OBJECT_ID('ops.TripStopShipments'))
    CREATE NONCLUSTERED INDEX IX_TripStopShipments_TripId ON ops.TripStopShipments (TripId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TripStopShipments_ShipmentId' AND object_id = OBJECT_ID('ops.TripStopShipments'))
    CREATE NONCLUSTERED INDEX IX_TripStopShipments_ShipmentId ON ops.TripStopShipments (ShipmentId);
GO
