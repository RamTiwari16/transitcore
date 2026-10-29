/*
  Purpose:      Seed data for Countries, Cities, StatusCodes, UnitsOfMeasure.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 005_lookup_extended.sql
*/
SET NOCOUNT ON;
GO

MERGE lookup.Countries AS target
USING (VALUES
    ('IND', 'India'), ('USA', 'United States'), ('GBR', 'United Kingdom'),
    ('ARE', 'United Arab Emirates'), ('SGP', 'Singapore'), ('DEU', 'Germany'),
    ('AUS', 'Australia'), ('CAN', 'Canada'), ('ZAF', 'South Africa'), ('BRA', 'Brazil')
) AS source (Code, Name)
ON target.Code = source.Code
WHEN NOT MATCHED THEN
    INSERT (Code, Name, CreatedBy) VALUES (source.Code, source.Name, 'seed');
GO

MERGE lookup.Cities AS target
USING (
    SELECT v.Name, co.Id AS CountryId
    FROM (VALUES
        ('Mumbai', 'IND'), ('Delhi', 'IND'), ('Bengaluru', 'IND'), ('Chennai', 'IND'),
        ('Kolkata', 'IND'), ('Hyderabad', 'IND'), ('Pune', 'IND'), ('Ahmedabad', 'IND'),
        ('Jaipur', 'IND'), ('Lucknow', 'IND'), ('Kochi', 'IND'), ('Nagpur', 'IND'),
        ('New York', 'USA'), ('Los Angeles', 'USA'), ('Chicago', 'USA'),
        ('London', 'GBR'), ('Manchester', 'GBR'),
        ('Dubai', 'ARE'), ('Abu Dhabi', 'ARE'),
        ('Singapore', 'SGP')
    ) AS v (Name, CountryCode)
    INNER JOIN lookup.Countries co ON co.Code = v.CountryCode
) AS source (Name, CountryId)
ON target.Name = source.Name
WHEN NOT MATCHED THEN
    INSERT (Name, CountryId, CreatedBy) VALUES (source.Name, source.CountryId, 'seed');
GO

MERGE lookup.StatusCodes AS target
USING (VALUES
    ('Vehicle', 'ACTIVE', 'Active', 1), ('Vehicle', 'MAINTENANCE', 'In Maintenance', 2), ('Vehicle', 'RETIRED', 'Retired', 3),
    ('Driver', 'ACTIVE', 'Active', 1), ('Driver', 'ON_LEAVE', 'On Leave', 2), ('Driver', 'INACTIVE', 'Inactive', 3),
    ('Trip', 'SCHEDULED', 'Scheduled', 1), ('Trip', 'IN_TRANSIT', 'In Transit', 2), ('Trip', 'DELAYED', 'Delayed', 3),
    ('Trip', 'COMPLETED', 'Completed', 4), ('Trip', 'CANCELLED', 'Cancelled', 5),
    ('Shipment', 'PENDING', 'Pending', 1), ('Shipment', 'BOOKED', 'Booked', 2), ('Shipment', 'IN_TRANSIT', 'In Transit', 3),
    ('Shipment', 'DELIVERED', 'Delivered', 4), ('Shipment', 'CANCELLED', 'Cancelled', 5),
    ('Invoice', 'DRAFT', 'Draft', 1), ('Invoice', 'SENT', 'Sent', 2), ('Invoice', 'PARTIALLY_PAID', 'Partially Paid', 3),
    ('Invoice', 'PAID', 'Paid', 4), ('Invoice', 'OVERDUE', 'Overdue', 5), ('Invoice', 'VOID', 'Void', 6)
) AS source (Category, Code, Name, SortOrder)
ON target.Category = source.Category AND target.Code = source.Code
WHEN NOT MATCHED THEN
    INSERT (Category, Code, Name, SortOrder, CreatedBy) VALUES (source.Category, source.Code, source.Name, source.SortOrder, 'seed');
GO

MERGE lookup.UnitsOfMeasure AS target
USING (VALUES
    ('KG', 'Kilogram'), ('TON', 'Metric Ton'), ('LTR', 'Litre'), ('PCS', 'Pieces'),
    ('BOX', 'Box'), ('PLT', 'Pallet'), ('CTN', 'Carton'), ('DOZ', 'Dozen'),
    ('M3', 'Cubic Meter'), ('KM', 'Kilometer')
) AS source (Code, Name)
ON target.Code = source.Code
WHEN NOT MATCHED THEN
    INSERT (Code, Name, CreatedBy) VALUES (source.Code, source.Name, 'seed');
GO
