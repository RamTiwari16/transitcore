/*
  Purpose:      Seed default mandatory vehicle compliance document types
                (F8). Staff can add/deactivate more via the lookup admin
                screens - this is just a sensible starting set.
  Author:       TransitCore rebuild
  Date:         2026-09-29
  Dependencies: 020_compliance_documents_eway_bills_schema.sql
*/
SET NOCOUNT ON;
GO

-- Spelled to match the DocumentType values already used in
-- fleet.VehicleDocuments seed data (e.g. "Fitness Certificate" with a
-- space) - this is freeform NVARCHAR with no enforced enum, so an exact
-- match here is what makes the dispatch compliance check actually work
-- against real rows instead of always reporting "Missing".
MERGE fleet.RequiredComplianceDocumentTypes AS target
USING (VALUES
    ('Insurance'), ('Permit'), ('Fitness Certificate'), ('PUC')
) AS source (DocumentType)
ON target.DocumentType = source.DocumentType
WHEN NOT MATCHED THEN
    INSERT (DocumentType, CreatedBy) VALUES (source.DocumentType, 'seed');
GO
