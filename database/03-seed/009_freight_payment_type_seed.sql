/*
  Purpose:      Phase 1 (F1 + F2) seed data - the FreightPaymentType status
                codes (Paid / ToPay / ToBeBilled) that ops.Shipments.
                FreightPaymentTypeId references, and the single global
                consignment-note numbering format used by any branch that
                doesn't have its own override row.
  Author:       TransitCore rebuild
  Date:         2026-09-24
  Dependencies: 003_lookup_extended_seed.sql (lookup.StatusCodes),
                01-schema/014_freight_parties_consignment_notes_schema.sql
                (ops.ConsignmentNoteNumberFormats)

  Note: the FreightPaymentType rows are actually seeded inside
  01-schema/014 itself (its own Shipments backfill needs them before any
  03-seed file runs) - the MERGE below is a harmless WHEN-NOT-MATCHED no-op
  that just keeps this category's canonical seed data visible here too,
  alongside every other StatusCodes category.
*/
SET NOCOUNT ON;
GO

MERGE lookup.StatusCodes AS target
USING (VALUES
    ('FreightPaymentType', 'PAID', 'Paid', 1),
    ('FreightPaymentType', 'TOPAY', 'To Pay', 2),
    ('FreightPaymentType', 'TOBEBILLED', 'To Be Billed', 3)
) AS source (Category, Code, Name, SortOrder)
ON target.Category = source.Category AND target.Code = source.Code
WHEN NOT MATCHED THEN
    INSERT (Category, Code, Name, SortOrder, CreatedBy) VALUES (source.Category, source.Code, source.Name, source.SortOrder, 'seed');
GO

IF NOT EXISTS (SELECT 1 FROM ops.ConsignmentNoteNumberFormats WHERE BranchId IS NULL AND IsDeleted = 0)
    INSERT INTO ops.ConsignmentNoteNumberFormats (BranchId, FormatTemplate, SequencePadding, CreatedBy)
    VALUES (NULL, '{BRANCH}/{FY}/{SEQ}', 5, 'seed');
GO
