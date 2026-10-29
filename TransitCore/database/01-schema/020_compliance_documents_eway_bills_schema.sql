/*
  Purpose:      Phase 6 (F8) of the freight-carrier feature set - transit
                compliance documents:
                (1) Permits/regulatory certs with expiry alerts - reuses the
                    existing fleet.VehicleDocuments/fleet.DriverLicenses
                    tables (already have DocumentType/ExpiryDate), adds only
                    the missing piece: a config table naming which vehicle
                    document types are mandatory, so an expiry/dispatch
                    report has something to check against.
                (2) Per-trip dispatch compliance checklist - reads the same
                    tables via a new non-blocking check proc (mirrors how
                    usp_CheckTripConflicts already works: the DB never
                    blocks a status change itself, the frontend decides what
                    to do with the check result).
                (3) E-way bills - added directly to ops.ConsignmentNotes,
                    since a CN already IS "the document accompanying the
                    goods movement" - no new table needed. Validity dates
                    are staff-entered from the actual generated e-way bill,
                    not computed from a distance/GST formula (that ruleset
                    is external and changes independently of this system).
  Author:       TransitCore rebuild
  Date:         2026-09-29
  Dependencies: 006_fleet_schema.sql (VehicleDocuments, DriverLicenses),
                014_freight_parties_consignment_notes_schema.sql (ConsignmentNotes)
*/
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== Required compliance document types (vehicle-side config) ==========
-- Which fleet.VehicleDocuments.DocumentType values are mandatory for a
-- vehicle to be considered dispatch-compliant. Admin-configurable (not
-- hardcoded in the check proc) since different operators mandate different
-- documents. Driver compliance has no equivalent config - a driver simply
-- needs one current (non-expired) fleet.DriverLicenses row, which isn't a
-- configurable list.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('fleet.RequiredComplianceDocumentTypes') AND type = 'U')
BEGIN
    CREATE TABLE fleet.RequiredComplianceDocumentTypes
    (
        Id            INT IDENTITY(1,1) NOT NULL,
        DocumentType  NVARCHAR(100)     NOT NULL,
        IsActive      BIT               NOT NULL CONSTRAINT DF_RequiredComplianceDocumentTypes_IsActive DEFAULT 1,
        CreatedAt     DATETIME2(3)      NOT NULL CONSTRAINT DF_RequiredComplianceDocumentTypes_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy     NVARCHAR(256)     NULL,
        ModifiedAt    DATETIME2(3)      NULL,
        ModifiedBy    NVARCHAR(256)     NULL,
        IsDeleted     BIT               NOT NULL CONSTRAINT DF_RequiredComplianceDocumentTypes_IsDeleted DEFAULT 0,
        CONSTRAINT PK_RequiredComplianceDocumentTypes PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_RequiredComplianceDocumentTypes_DocumentType UNIQUE (DocumentType)
    );
END
GO

-- ========== E-way bill fields on the consignment note ==========

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ops.ConsignmentNotes') AND name = 'EwayBillNo')
    ALTER TABLE ops.ConsignmentNotes ADD
        EwayBillNo NVARCHAR(50) NULL,
        EwayBillGeneratedDate DATE NULL,
        EwayBillValidUntil DATE NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ConsignmentNotes_EwayBillValidUntil' AND object_id = OBJECT_ID('ops.ConsignmentNotes'))
    CREATE NONCLUSTERED INDEX IX_ConsignmentNotes_EwayBillValidUntil ON ops.ConsignmentNotes (EwayBillValidUntil) WHERE EwayBillValidUntil IS NOT NULL;
GO
