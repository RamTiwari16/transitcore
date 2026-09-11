/*
  Purpose:      Seed data for Customers.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 007_billing_customers_schema.sql
*/
SET NOCOUNT ON;
GO

MERGE billing.Customers AS target
USING (VALUES
    ('CUST001', 'Aarav Retail Pvt Ltd'), ('CUST002', 'Bharat Traders'), ('CUST003', 'Coastal Exports Ltd'),
    ('CUST004', 'Deccan Manufacturing Co'), ('CUST005', 'Everest Foods Pvt Ltd'), ('CUST006', 'Fusion Electronics'),
    ('CUST007', 'Ganges Pharma Ltd'), ('CUST008', 'Horizon Textiles'), ('CUST009', 'Indus Auto Parts'),
    ('CUST010', 'Jupiter Logistics Partner'), ('CUST011', 'Kaveri Agro Products'), ('CUST012', 'Lotus Consumer Goods'),
    ('CUST013', 'Meridian Chemicals'), ('CUST014', 'Northstar Retail Group'), ('CUST015', 'Orion Industrial Supplies')
) AS source (Code, Name)
ON target.Code = source.Code
WHEN NOT MATCHED THEN
    INSERT (Code, Name, CreatedBy) VALUES (source.Code, source.Name, 'seed');
GO
