/*
  Purpose:      Make (RouteId, StopOrder) unique among active stops only.
                Stops are soft-deleted, so the original UNIQUE constraint kept
                blocking a deleted stop's order number from ever being reused
                (delete the last stop, add a new one -> duplicate key).
                The filtered index keeps the constraint's name.
  Author:       TransitCore rebuild
  Date:         2026-09-25
  Dependencies: 008_ops_routes_trips_shipments_schema.sql
*/
-- Filtered indexes need QUOTED_IDENTIFIER ON, both here and in every proc
-- that writes to ops.RouteStops (see 02-programmability headers).
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

IF EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE name = 'UQ_RouteStops_Route_StopOrder' AND parent_object_id = OBJECT_ID('ops.RouteStops')
)
    ALTER TABLE ops.RouteStops DROP CONSTRAINT UQ_RouteStops_Route_StopOrder;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_RouteStops_Route_StopOrder' AND object_id = OBJECT_ID('ops.RouteStops'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_RouteStops_Route_StopOrder
        ON ops.RouteStops (RouteId, StopOrder)
        WHERE IsDeleted = 0;
GO
