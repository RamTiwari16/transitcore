/*
  Purpose:      Reference/lookup seed data — regions, branches, designations,
                working designations (~20 rows each).
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 001_lookup_core.sql
*/
SET NOCOUNT ON;
GO

MERGE lookup.Regions AS target
USING (VALUES
    ('North'), ('South'), ('East'), ('West'), ('Central'),
    ('North-East'), ('North-West'), ('South-East'), ('South-West'), ('Coastal')
) AS source (Name)
ON target.Name = source.Name
WHEN NOT MATCHED THEN
    INSERT (Name, CreatedBy) VALUES (source.Name, 'seed');
GO

MERGE lookup.Designations AS target
USING (VALUES
    ('MGR', 'Manager'), ('SUP', 'Supervisor'), ('EXE', 'Executive'),
    ('CLK', 'Clerk'), ('DRV', 'Driver'), ('TEC', 'Technician'),
    ('ADM', 'Administrator'), ('ACC', 'Accountant'), ('SEC', 'Security Officer'),
    ('HLP', 'Helper'), ('DSP', 'Dispatcher'), ('CSA', 'Customer Service Agent'),
    ('WHS', 'Warehouse Staff'), ('QAI', 'Quality Inspector'), ('FLM', 'Fleet Manager'),
    ('OPS', 'Operations Lead'), ('BIL', 'Billing Clerk'), ('HRM', 'HR Manager'),
    ('ITS', 'IT Support'), ('TRN', 'Trainer')
) AS source (Code, Name)
ON target.Code = source.Code
WHEN NOT MATCHED THEN
    INSERT (Code, Name, CreatedBy) VALUES (source.Code, source.Name, 'seed');
GO

MERGE lookup.WorkingDesignations AS target
USING (VALUES
    ('Field'), ('Office'), ('Warehouse'), ('Depot'), ('Remote'),
    ('On-Site'), ('Workshop'), ('Control Room'), ('Yard'), ('Branch Counter'),
    ('Regional Office'), ('Head Office'), ('Loading Bay'), ('Night Shift Desk'),
    ('Customer Site'), ('Toll Plaza'), ('Weighbridge'), ('Inspection Bay'),
    ('Vendor Site'), ('Training Center')
) AS source (Name)
ON target.Name = source.Name
WHEN NOT MATCHED THEN
    INSERT (Name, CreatedBy) VALUES (source.Name, 'seed');
GO

-- Code values match 01-schema/014_freight_parties_consignment_notes_schema.sql's
-- backfill mapping exactly (that file adds Code as NOT NULL) - kept in sync
-- here too since on a brand-new database run-all.sql runs every 01-schema
-- file, including that NOT NULL tightening, before any 03-seed file runs;
-- without Code supplied here, this INSERT would violate that constraint on
-- a from-scratch database (only an existing, already-seeded database's
-- rows get their Code via that file's own backfill UPDATE).
MERGE lookup.Branches AS target
USING (
    SELECT v.Name, rg.Id AS RegionId, v.Code
    FROM (VALUES
        ('Delhi Central', 'North', 'DEL'), ('Gurgaon Hub', 'North', 'GGN'), ('Chandigarh', 'North', 'CHD'),
        ('Chennai Port', 'South', 'CHN'), ('Bengaluru Tech Park', 'South', 'BLR'), ('Coimbatore', 'South', 'CBE'),
        ('Kolkata Docks', 'East', 'CCU'), ('Guwahati', 'North-East', 'GAU'), ('Bhubaneswar', 'East', 'BBI'),
        ('Mumbai Central', 'West', 'BOM'), ('Pune Depot', 'West', 'PNQ'), ('Ahmedabad', 'West', 'AMD'),
        ('Jaipur', 'North-West', 'JAI'), ('Hyderabad', 'South-East', 'HYD'), ('Kochi Port', 'South-West', 'COK'),
        ('Nagpur', 'Central', 'NAG'), ('Bhopal', 'Central', 'BHO'), ('Vizag Port', 'Coastal', 'VTZ'),
        ('Goa', 'Coastal', 'GOI'), ('Lucknow', 'North', 'LKO')
    ) AS v (Name, RegionName, Code)
    INNER JOIN lookup.Regions rg ON rg.Name = v.RegionName
) AS source (Name, RegionId, Code)
ON target.Name = source.Name
WHEN NOT MATCHED THEN
    INSERT (Name, RegionId, Code, CreatedBy) VALUES (source.Name, source.RegionId, source.Code, 'seed');
GO
