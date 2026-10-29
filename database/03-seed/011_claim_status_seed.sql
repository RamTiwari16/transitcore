/*
  Purpose:      Seed lookup.StatusCodes 'Claim' category for Phase 5 (F7).
  Author:       TransitCore rebuild
  Date:         2026-10-09
  Dependencies: 005_lookup_extended.sql, 019_empty_km_claims_schema.sql
*/
SET NOCOUNT ON;
GO

MERGE lookup.StatusCodes AS target
USING (VALUES
    ('Claim', 'RAISED', 'Raised', 1),
    ('Claim', 'UNDER_INVESTIGATION', 'Under Investigation', 2),
    ('Claim', 'SETTLED', 'Settled', 3),
    ('Claim', 'REJECTED', 'Rejected', 4)
) AS source (Category, Code, Name, SortOrder)
ON target.Category = source.Category AND target.Code = source.Code
WHEN NOT MATCHED THEN
    INSERT (Category, Code, Name, SortOrder, CreatedBy) VALUES (source.Category, source.Code, source.Name, source.SortOrder, 'seed');
GO
