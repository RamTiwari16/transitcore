/*
  Purpose:      Seed data for Routes and Trips (~30 trips across the last
                and next couple of weeks, to give the UI's trip listing and
                fleet utilisation views something realistic to show).
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 003_lookup_extended_seed.sql, 004_fleet_seed.sql,
                008_ops_routes_trips_shipments_schema.sql
*/
SET NOCOUNT ON;
GO

INSERT INTO ops.Routes (Name, OriginCityId, DestinationCityId, DistanceKm, CreatedBy)
SELECT r.Name, oc.Id, dc.Id, r.DistanceKm, 'seed'
FROM (VALUES
    ('Mumbai - Delhi',      'Mumbai',   'Delhi',     1400),
    ('Mumbai - Bengaluru',  'Mumbai',   'Bengaluru', 980),
    ('Delhi - Kolkata',     'Delhi',    'Kolkata',   1500),
    ('Chennai - Hyderabad', 'Chennai',  'Hyderabad', 630),
    ('Bengaluru - Chennai', 'Bengaluru','Chennai',   350),
    ('Pune - Ahmedabad',    'Pune',     'Ahmedabad', 660),
    ('Delhi - Jaipur',      'Delhi',    'Jaipur',    280),
    ('Kolkata - Lucknow',   'Kolkata',  'Lucknow',   1000),
    ('Hyderabad - Nagpur',  'Hyderabad','Nagpur',    500),
    ('Kochi - Chennai',     'Kochi',    'Chennai',   680)
) AS r (Name, OriginCityName, DestinationCityName, DistanceKm)
INNER JOIN lookup.Cities oc ON oc.Name = r.OriginCityName
INNER JOIN lookup.Cities dc ON dc.Name = r.DestinationCityName
WHERE NOT EXISTS (SELECT 1 FROM ops.Routes ex WHERE ex.Name = r.Name);
GO

-- ~30 trips: one per (route, day-offset) combination below, spread across
-- vehicles/drivers by row number so the set is deterministic and idempotent.
-- Dates are anchored to a fixed date (not SYSUTCDATETIME()) so re-running
-- this script never creates a second batch - a moving "today" would break
-- idempotency across days.
DECLARE @SeedAnchorDate DATE = '2026-09-11';

INSERT INTO ops.Trips (RouteId, VehicleId, DriverId, ScheduledDeparture, ScheduledArrival, StatusId, CreatedBy)
SELECT
    r.Id,
    v.Id,
    d.Id,
    DATEADD(DAY, t.DayOffset, @SeedAnchorDate),
    DATEADD(HOUR, t.DurationHours, DATEADD(DAY, t.DayOffset, @SeedAnchorDate)),
    sc.Id,
    'seed'
FROM (VALUES
    (1, -10, 18, 'COMPLETED'), (2, -9, 14, 'COMPLETED'), (3, -8, 20, 'COMPLETED'),
    (4, -8, 9,  'COMPLETED'),  (5, -7, 5,  'COMPLETED'), (6, -7, 10, 'COMPLETED'),
    (7, -6, 4,  'COMPLETED'),  (8, -6, 15, 'COMPLETED'), (9, -5, 8,  'COMPLETED'),
    (10,-5, 12, 'COMPLETED'),  (1, -4, 18, 'COMPLETED'), (2, -4, 14, 'COMPLETED'),
    (3, -3, 20, 'COMPLETED'),  (4, -3, 9,  'COMPLETED'), (5, -2, 5,  'IN_TRANSIT'),
    (6, -2, 10, 'IN_TRANSIT'),(7, -1, 4,  'IN_TRANSIT'),(8, -1, 15, 'DELAYED'),
    (9,  0, 8,  'SCHEDULED'), (10, 0, 12, 'SCHEDULED'), (1,  1, 18, 'SCHEDULED'),
    (2,  1, 14, 'SCHEDULED'), (3,  2, 20, 'SCHEDULED'), (4,  2, 9,  'SCHEDULED'),
    (5,  3, 5,  'SCHEDULED'), (6,  3, 10, 'SCHEDULED'), (7,  4, 4,  'SCHEDULED'),
    (8,  4, 15, 'SCHEDULED'),(9,  5, 8,  'SCHEDULED'), (10, 5, 12, 'SCHEDULED')
) AS t (RouteOrdinal, DayOffset, DurationHours, StatusCode)
INNER JOIN (SELECT Id, ROW_NUMBER() OVER (ORDER BY Id) AS Ordinal FROM ops.Routes) r ON r.Ordinal = t.RouteOrdinal
INNER JOIN (SELECT Id, ROW_NUMBER() OVER (ORDER BY Id) AS Ordinal FROM fleet.Vehicles) v ON v.Ordinal = ((t.RouteOrdinal + ABS(t.DayOffset)) % 20) + 1
INNER JOIN (SELECT Id, ROW_NUMBER() OVER (ORDER BY Id) AS Ordinal FROM fleet.Drivers) d ON d.Ordinal = ((t.RouteOrdinal + ABS(t.DayOffset)) % 15) + 1
INNER JOIN lookup.StatusCodes sc ON sc.Category = 'Trip' AND sc.Code = t.StatusCode
WHERE NOT EXISTS (
    SELECT 1 FROM ops.Trips ex
    WHERE ex.RouteId = r.Id
      AND ex.ScheduledDeparture = DATEADD(DAY, t.DayOffset, @SeedAnchorDate)
);
GO
