/*
  Purpose:      Seed data for ~10 shipments with items, so the Shipments UI
                has something to show.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 003_lookup_extended_seed.sql, 004_fleet_seed.sql,
                005_billing_customers_seed.sql, 009_ops_shipment_procs.sql
*/
SET NOCOUNT ON;
GO

DECLARE @SeedAnchorDate DATE = '2026-09-11';

-- FreightPaymentTypeId defaults every seeded shipment to ToBeBilled, same
-- default 01-schema/014_freight_parties_consignment_notes_schema.sql's
-- backfill uses for pre-existing rows - that column is NOT NULL and this
-- file's own INSERT needs to supply it directly on a from-scratch database
-- (01-schema, including that NOT NULL tightening, runs before any 03-seed
-- file in run-all.sql).
DECLARE @ToBeBilledStatusId INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'FreightPaymentType' AND Code = 'TOBEBILLED');

INSERT INTO ops.Shipments (CustomerId, OriginCityId, DestinationCityId, StatusId, ShipmentDate, FreightPaymentTypeId, ConsignorCustomerId, CreatedBy)
SELECT c.Id, oc.Id, dc.Id, sc.Id, DATEADD(DAY, s.DayOffset, @SeedAnchorDate), @ToBeBilledStatusId, c.Id, 'seed'
FROM (VALUES
    ('CUST001', 'Mumbai',   'Delhi',     -8, 'DELIVERED'),
    ('CUST002', 'Mumbai',   'Bengaluru', -7, 'DELIVERED'),
    ('CUST003', 'Chennai',  'Hyderabad', -6, 'DELIVERED'),
    ('CUST004', 'Bengaluru','Chennai',   -5, 'IN_TRANSIT'),
    ('CUST005', 'Pune',     'Ahmedabad', -4, 'IN_TRANSIT'),
    ('CUST006', 'Delhi',    'Jaipur',    -3, 'BOOKED'),
    ('CUST007', 'Kolkata',  'Lucknow',   -2, 'BOOKED'),
    ('CUST008', 'Hyderabad','Nagpur',    -1, 'PENDING'),
    ('CUST009', 'Kochi',    'Chennai',    0, 'PENDING'),
    ('CUST010', 'Mumbai',   'Delhi',      1, 'PENDING')
) AS s (CustomerCode, OriginCityName, DestinationCityName, DayOffset, StatusCode)
INNER JOIN billing.Customers c ON c.Code = s.CustomerCode
INNER JOIN lookup.Cities oc ON oc.Name = s.OriginCityName
INNER JOIN lookup.Cities dc ON dc.Name = s.DestinationCityName
INNER JOIN lookup.StatusCodes sc ON sc.Category = 'Shipment' AND sc.Code = s.StatusCode
WHERE NOT EXISTS (
    SELECT 1 FROM ops.Shipments ex
    WHERE ex.CustomerId = c.Id AND ex.ShipmentDate = DATEADD(DAY, s.DayOffset, @SeedAnchorDate)
);
GO

INSERT INTO ops.ShipmentItems (ShipmentId, Description, Quantity, UnitOfMeasureId, WeightKg, CreatedBy)
SELECT sh.Id, i.Description, i.Quantity, uom.Id, i.WeightKg, 'seed'
FROM (
    SELECT sh.Id, ROW_NUMBER() OVER (ORDER BY sh.Id) AS Ordinal
    FROM ops.Shipments sh
    WHERE sh.CreatedBy = 'seed'
) sh
CROSS APPLY (VALUES
    ('General cargo', 1, 'PCS', 250.00)
) AS i (Description, Quantity, UnitCode, WeightKg)
INNER JOIN lookup.UnitsOfMeasure uom ON uom.Code = i.UnitCode
WHERE NOT EXISTS (SELECT 1 FROM ops.ShipmentItems ex WHERE ex.ShipmentId = sh.Id);
GO
