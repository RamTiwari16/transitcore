/*
  Purpose:      Phase 4 (F5) seed data - VendorBill status codes, a distinct
                category from Invoice's (kept separate rather than reused,
                so filtering/reporting on one never silently includes rows
                from the other) but mirroring the same lifecycle states.
  Author:       TransitCore rebuild
  Date:         2026-10-05
  Dependencies: 003_lookup_extended_seed.sql (lookup.StatusCodes)
*/
SET NOCOUNT ON;
GO

MERGE lookup.StatusCodes AS target
USING (VALUES
    ('VendorBill', 'DRAFT', 'Draft', 1),
    ('VendorBill', 'SENT', 'Sent', 2),
    ('VendorBill', 'PARTIALLY_PAID', 'Partially Paid', 3),
    ('VendorBill', 'PAID', 'Paid', 4),
    ('VendorBill', 'OVERDUE', 'Overdue', 5),
    ('VendorBill', 'VOID', 'Void', 6)
) AS source (Category, Code, Name, SortOrder)
ON target.Category = source.Category AND target.Code = source.Code
WHEN NOT MATCHED THEN
    INSERT (Category, Code, Name, SortOrder, CreatedBy) VALUES (source.Category, source.Code, source.Name, source.SortOrder, 'seed');
GO
