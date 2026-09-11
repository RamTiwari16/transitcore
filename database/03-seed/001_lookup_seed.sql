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

MERGE lookup.Branches AS target
USING (
    SELECT v.Name, rg.Id AS RegionId
    FROM (VALUES
        ('Delhi Central', 'North'), ('Gurgaon Hub', 'North'), ('Chandigarh', 'North'),
        ('Chennai Port', 'South'), ('Bengaluru Tech Park', 'South'), ('Coimbatore', 'South'),
        ('Kolkata Docks', 'East'), ('Guwahati', 'North-East'), ('Bhubaneswar', 'East'),
        ('Mumbai Central', 'West'), ('Pune Depot', 'West'), ('Ahmedabad', 'West'),
        ('Jaipur', 'North-West'), ('Hyderabad', 'South-East'), ('Kochi Port', 'South-West'),
        ('Nagpur', 'Central'), ('Bhopal', 'Central'), ('Vizag Port', 'Coastal'),
        ('Goa', 'Coastal'), ('Lucknow', 'North')
    ) AS v (Name, RegionName)
    INNER JOIN lookup.Regions rg ON rg.Name = v.RegionName
) AS source (Name, RegionId)
ON target.Name = source.Name
WHEN NOT MATCHED THEN
    INSERT (Name, RegionId, CreatedBy) VALUES (source.Name, source.RegionId, 'seed');
GO
