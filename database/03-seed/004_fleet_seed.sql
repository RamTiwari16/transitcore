/*
  Purpose:      Seed data for VehicleTypes, Vehicles, Drivers.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 003_lookup_extended_seed.sql, 006_fleet_schema.sql
*/
SET NOCOUNT ON;
GO

-- CapacityCbm values are rough, reasonable-for-demo-data estimates (not
-- precise real-world dimensions) - there's no admin CRUD endpoint for
-- VehicleTypes in the app today, so seed data (here, MERGE-inserted) plus
-- 01-schema/015's own backfill (for names already in an existing database)
-- are the only ways this column gets populated at all.
MERGE fleet.VehicleTypes AS target
USING (VALUES
    ('Small Truck', 'Up to 3 ton payload', 3000, 9),
    ('Medium Truck', 'Up to 8 ton payload', 8000, 20),
    ('Large Truck', 'Up to 16 ton payload', 16000, 35),
    ('Container Truck', '20/40 ft container carrier', 28000, 45),
    ('Trailer', 'Multi-axle trailer', 35000, 55),
    ('Refrigerated Truck', 'Temperature-controlled cargo', 10000, 18),
    ('Tanker', 'Bulk liquid transport', 20000, 20),
    ('Van', 'Last-mile / light cargo', 1200, 6)
) AS source (Name, Description, CapacityKg, CapacityCbm)
ON target.Name = source.Name
WHEN NOT MATCHED THEN
    INSERT (Name, Description, CapacityKg, CapacityCbm, CreatedBy) VALUES (source.Name, source.Description, source.CapacityKg, source.CapacityCbm, 'seed');
GO

-- Vehicles inherit their type's CapacityCbm directly (no per-vehicle figure
-- in this seed data, matching how each vehicle's own CapacityKg IS
-- hand-tuned per row but CapacityCbm has no equivalent hand-tuned source).
INSERT INTO fleet.Vehicles (RegistrationNo, VehicleTypeId, Make, Model, ManufactureYear, CapacityKg, CapacityCbm, StatusId, CreatedBy)
SELECT v.RegistrationNo, vt.Id, v.Make, v.Model, v.ManufactureYear, v.CapacityKg, vt.CapacityCbm, sc.Id, 'seed'
FROM (VALUES
    ('TC-DL-01-1001', 'Small Truck',       'Tata',     'Ace',        2021, 3000,  'ACTIVE'),
    ('TC-DL-01-1002', 'Small Truck',       'Mahindra', 'Bolero Pik', 2022, 2800,  'ACTIVE'),
    ('TC-MH-02-1003', 'Medium Truck',      'Ashok Leyland', 'Dost',  2020, 7500,  'ACTIVE'),
    ('TC-MH-02-1004', 'Medium Truck',      'Eicher',   'Pro 2049',   2021, 8000,  'ACTIVE'),
    ('TC-KA-03-1005', 'Large Truck',       'Tata',     'Signa 3118', 2019, 16000, 'ACTIVE'),
    ('TC-KA-03-1006', 'Large Truck',       'BharatBenz','3123R',     2020, 15500, 'MAINTENANCE'),
    ('TC-TN-04-1007', 'Container Truck',   'Volvo',    'FMX',        2022, 28000, 'ACTIVE'),
    ('TC-TN-04-1008', 'Container Truck',   'Tata',     'Prima',      2021, 27500, 'ACTIVE'),
    ('TC-GJ-05-1009', 'Trailer',           'Ashok Leyland', 'U-Truk',2018, 34000, 'ACTIVE'),
    ('TC-GJ-05-1010', 'Trailer',           'Eicher',   'Terra 31',   2019, 35000, 'MAINTENANCE'),
    ('TC-WB-06-1011', 'Refrigerated Truck','Tata',     'Signa 2818', 2022, 10000, 'ACTIVE'),
    ('TC-WB-06-1012', 'Refrigerated Truck','Isuzu',    'FTR',        2021, 9500,  'ACTIVE'),
    ('TC-RJ-07-1013', 'Tanker',            'BharatBenz','1617R',     2020, 20000, 'ACTIVE'),
    ('TC-RJ-07-1014', 'Tanker',            'Tata',     'Signa 2523', 2019, 19500, 'RETIRED'),
    ('TC-UP-08-1015', 'Van',               'Force',    'Traveller',  2022, 1200,  'ACTIVE'),
    ('TC-UP-08-1016', 'Van',               'Tata',     'Ace Gold',   2021, 1000,  'ACTIVE'),
    ('TC-PB-09-1017', 'Small Truck',       'Mahindra', 'Jeeto',      2023, 700,   'ACTIVE'),
    ('TC-PB-09-1018', 'Medium Truck',      'Tata',     '407 Gold',   2020, 4000,  'ACTIVE'),
    ('TC-HR-10-1019', 'Large Truck',       'Eicher',   'Pro 6031',   2022, 16000, 'ACTIVE'),
    ('TC-HR-10-1020', 'Container Truck',   'Volvo',    'FH',         2023, 28500, 'ACTIVE')
) AS v (RegistrationNo, VehicleTypeName, Make, Model, ManufactureYear, CapacityKg, StatusCode)
INNER JOIN fleet.VehicleTypes vt ON vt.Name = v.VehicleTypeName
INNER JOIN lookup.StatusCodes sc ON sc.Category = 'Vehicle' AND sc.Code = v.StatusCode
WHERE NOT EXISTS (SELECT 1 FROM fleet.Vehicles ex WHERE ex.RegistrationNo = v.RegistrationNo);
GO

INSERT INTO fleet.Drivers (FullName, PhoneNo, Email, HireDate, StatusId, CreatedBy)
SELECT d.FullName, d.PhoneNo, d.Email, d.HireDate, sc.Id, 'seed'
FROM (VALUES
    ('Ramesh Kumar',    '+919810000001', 'ramesh.kumar@transitcore.local',    '2019-03-01', 'ACTIVE'),
    ('Suresh Patil',    '+919810000002', 'suresh.patil@transitcore.local',    '2020-06-15', 'ACTIVE'),
    ('Anil Sharma',     '+919810000003', 'anil.sharma@transitcore.local',     '2018-11-20', 'ACTIVE'),
    ('Vijay Singh',     '+919810000004', 'vijay.singh@transitcore.local',     '2021-01-10', 'ACTIVE'),
    ('Manoj Yadav',     '+919810000005', 'manoj.yadav@transitcore.local',     '2019-08-05', 'ON_LEAVE'),
    ('Rajesh Gupta',    '+919810000006', 'rajesh.gupta@transitcore.local',    '2020-02-14', 'ACTIVE'),
    ('Deepak Verma',    '+919810000007', 'deepak.verma@transitcore.local',    '2022-04-01', 'ACTIVE'),
    ('Sanjay Mishra',   '+919810000008', 'sanjay.mishra@transitcore.local',   '2017-09-19', 'ACTIVE'),
    ('Ashok Reddy',     '+919810000009', 'ashok.reddy@transitcore.local',     '2021-07-22', 'ACTIVE'),
    ('Prakash Nair',    '+919810000010', 'prakash.nair@transitcore.local',    '2020-10-30', 'ACTIVE'),
    ('Mahesh Joshi',    '+919810000011', 'mahesh.joshi@transitcore.local',    '2019-05-17', 'INACTIVE'),
    ('Naveen Rao',      '+919810000012', 'naveen.rao@transitcore.local',      '2022-01-25', 'ACTIVE'),
    ('Kiran Bhat',      '+919810000013', 'kiran.bhat@transitcore.local',      '2021-11-11', 'ACTIVE'),
    ('Ravi Chauhan',    '+919810000014', 'ravi.chauhan@transitcore.local',    '2018-02-28', 'ACTIVE'),
    ('Sunil Malhotra',  '+919810000015', 'sunil.malhotra@transitcore.local',  '2023-03-06', 'ACTIVE')
) AS d (FullName, PhoneNo, Email, HireDate, StatusCode)
INNER JOIN lookup.StatusCodes sc ON sc.Category = 'Driver' AND sc.Code = d.StatusCode
WHERE NOT EXISTS (SELECT 1 FROM fleet.Drivers ex WHERE ex.Email = d.Email);
GO
