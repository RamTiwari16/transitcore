/*
  Purpose:      Phase 1 (F1 + F2) of the freight-carrier feature set.
                F1: Shipment consignor/consignee/billing-party split and a
                FreightPaymentType classification (Paid/ToPay/ToBeBilled);
                billing.Payments can now target a Shipment directly (for
                ToPay collections at delivery) instead of only an Invoice.
                F2: consignment notes (one per shipment), auto-numbered per
                branch per financial year via a concurrency-safe reserved
                sequence and an admin-configurable format template.
  Author:       TransitCore rebuild
  Date:         2026-09-24
  Dependencies: 002_identity_schema.sql (auth.Users, auth.UserBranches),
                001_lookup_core.sql (lookup.Branches),
                008_ops_routes_trips_shipments_schema.sql (ops.Shipments),
                009_billing_invoicing_schema.sql (billing.Payments)

  Design notes:
  - BillingParty is NOT a new column - it already exists as Shipments.CustomerId
    (kept as-is, zero breaking change to existing readers/writers of that
    column). Only Consignor and Consignee are new, each optionally linking to
    a real Customer OR carrying ad-hoc name/address/phone for a one-off
    sender/receiver that isn't a Customer record.
  - FreightPaymentType reuses the existing lookup.StatusCodes(Category, Code)
    generic-lookup mechanism (seeded in 03-seed), the same mechanism already
    used for Shipment/Trip/Invoice status lifecycles - no new table needed.
  - Consignment-note numbering: ops.ConsignmentNoteSequences is the atomic
    per-(Branch, FinancialYear) counter; ops.ConsignmentNoteNumberFormats
    holds the admin-editable {BRANCH}/{FY}/{SEQ}-style template per branch
    (or a single global fallback row where BranchId IS NULL). Both the
    sequence reservation and the CN insert happen inside ops.usp_InsertShipment
    itself (see 026_freight_parties_consignment_notes_procs.sql) so a failed
    shipment insert can never leave behind a reserved-but-unused sequence
    number ("no gaps from failed saves").
  - Branch, for numbering purposes, is resolved from the CURRENT USER's
    primary branch (auth.UserBranches.IsPrimary), not entered by staff -
    UserBranches had no "primary" concept before this file.
*/
SET NOCOUNT ON;
GO

-- ========== lookup.Branches: short Code for CN numbering ==========

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('lookup.Branches') AND name = 'Code')
BEGIN
    ALTER TABLE lookup.Branches ADD Code NVARCHAR(10) NULL;
END
GO

-- Backfill: hand-assigned, airport-code-style abbreviations for the 20
-- branches seeded in 03-seed/001_lookup_seed.sql - unique and readable
-- rather than an auto-truncated name that could collide.
UPDATE lookup.Branches
SET Code = CASE Name
    WHEN 'Delhi Central'        THEN 'DEL'
    WHEN 'Gurgaon Hub'          THEN 'GGN'
    WHEN 'Chandigarh'           THEN 'CHD'
    WHEN 'Chennai Port'         THEN 'CHN'
    WHEN 'Bengaluru Tech Park'  THEN 'BLR'
    WHEN 'Coimbatore'           THEN 'CBE'
    WHEN 'Kolkata Docks'        THEN 'CCU'
    WHEN 'Guwahati'             THEN 'GAU'
    WHEN 'Bhubaneswar'          THEN 'BBI'
    WHEN 'Mumbai Central'       THEN 'BOM'
    WHEN 'Pune Depot'           THEN 'PNQ'
    WHEN 'Ahmedabad'            THEN 'AMD'
    WHEN 'Jaipur'               THEN 'JAI'
    WHEN 'Hyderabad'            THEN 'HYD'
    WHEN 'Kochi Port'           THEN 'COK'
    WHEN 'Nagpur'               THEN 'NAG'
    WHEN 'Bhopal'               THEN 'BHO'
    WHEN 'Vizag Port'           THEN 'VTZ'
    WHEN 'Goa'                  THEN 'GOI'
    WHEN 'Lucknow'              THEN 'LKO'
    ELSE Code
END
WHERE Code IS NULL;
GO

-- Any branch added after this file (or one of the 20 above renamed) will
-- leave Code NULL and this ALTER will fail loudly rather than silently
-- allow an un-coded branch - that's deliberate: a human needs to assign it.
ALTER TABLE lookup.Branches ALTER COLUMN Code NVARCHAR(10) NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Branches_Code' AND object_id = OBJECT_ID('lookup.Branches'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Branches_Code ON lookup.Branches (Code);
GO

-- ========== auth.UserBranches: primary-branch flag ==========

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('auth.UserBranches') AND name = 'IsPrimary')
BEGIN
    ALTER TABLE auth.UserBranches ADD IsPrimary BIT NOT NULL CONSTRAINT DF_UserBranches_IsPrimary DEFAULT 0;
END
GO

-- Backfill: each existing user's lowest BranchId becomes their primary, so
-- every user who already has at least one branch ends up with exactly one.
;WITH FirstBranch AS (
    SELECT UserId, MIN(BranchId) AS BranchId
    FROM auth.UserBranches
    GROUP BY UserId
)
UPDATE ub
SET IsPrimary = 1
FROM auth.UserBranches ub
INNER JOIN FirstBranch fb ON fb.UserId = ub.UserId AND fb.BranchId = ub.BranchId
WHERE NOT EXISTS (SELECT 1 FROM auth.UserBranches x WHERE x.UserId = ub.UserId AND x.IsPrimary = 1);
GO

-- At most one primary branch per user, enforced at the data level (not just
-- by the proc that maintains it). Filtered index - needs QUOTED_IDENTIFIER
-- ON in its own batch first (same fix as 012_ops_phase3_schema.sql's
-- TrackingNo filtered index).
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_UserBranches_OnePrimaryPerUser' AND object_id = OBJECT_ID('auth.UserBranches'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_UserBranches_OnePrimaryPerUser ON auth.UserBranches (UserId) WHERE IsPrimary = 1;
GO

-- ========== ops.Shipments: consignor / consignee / freight payment type ==========

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ops.Shipments') AND name = 'ConsignorCustomerId')
BEGIN
    ALTER TABLE ops.Shipments ADD
        ConsignorCustomerId  INT           NULL,
        ConsignorName        NVARCHAR(200) NULL,
        ConsignorAddress     NVARCHAR(300) NULL,
        ConsignorPhone       NVARCHAR(30)  NULL,
        ConsigneeCustomerId  INT           NULL,
        ConsigneeName        NVARCHAR(200) NULL,
        ConsigneeAddress     NVARCHAR(300) NULL,
        ConsigneePhone       NVARCHAR(30)  NULL,
        FreightPaymentTypeId INT           NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Shipments_ConsignorCustomer')
    ALTER TABLE ops.Shipments ADD CONSTRAINT FK_Shipments_ConsignorCustomer FOREIGN KEY (ConsignorCustomerId) REFERENCES billing.Customers (Id) ON DELETE NO ACTION;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Shipments_ConsigneeCustomer')
    ALTER TABLE ops.Shipments ADD CONSTRAINT FK_Shipments_ConsigneeCustomer FOREIGN KEY (ConsigneeCustomerId) REFERENCES billing.Customers (Id) ON DELETE NO ACTION;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Shipments_FreightPaymentType')
    ALTER TABLE ops.Shipments ADD CONSTRAINT FK_Shipments_FreightPaymentType FOREIGN KEY (FreightPaymentTypeId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION;
GO

-- The FreightPaymentType codes are seeded HERE, not in 03-seed, because
-- run-all.sql runs every 01-schema file before any 03-seed file - the
-- backfill immediately below needs TOBEBILLED to already exist. (03-seed's
-- own MERGE for the same rows is a WHEN NOT MATCHED no-op if this already
-- ran; kept there too since 03-seed is the canonical seed-data home other
-- StatusCodes rows live in.)
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

-- Backfill per the spec: existing shipments -> Consignor = BillingParty
-- (i.e. the existing CustomerId) = current customer, type = ToBeBilled.
-- BillingParty itself needs no backfill since it IS the existing CustomerId
-- column, unchanged.
UPDATE s
SET ConsignorCustomerId = s.CustomerId,
    FreightPaymentTypeId = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'FreightPaymentType' AND Code = 'TOBEBILLED')
FROM ops.Shipments s
WHERE s.FreightPaymentTypeId IS NULL;
GO

ALTER TABLE ops.Shipments ALTER COLUMN FreightPaymentTypeId INT NOT NULL;
GO

-- ========== billing.Payments: allow targeting a Shipment directly ==========
-- Needed for F1's "ToPay: at delivery, staff record the amount collected".
-- Loosening InvoiceId from NOT NULL to NULL is backward compatible - every
-- existing caller already always supplies it, so no existing row or code
-- path is affected; it only opens up a new optional path.

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('billing.Payments') AND name = 'InvoiceId' AND is_nullable = 0
)
BEGIN
    ALTER TABLE billing.Payments DROP CONSTRAINT FK_Payments_Invoices;
    ALTER TABLE billing.Payments ALTER COLUMN InvoiceId INT NULL;
    ALTER TABLE billing.Payments ADD CONSTRAINT FK_Payments_Invoices FOREIGN KEY (InvoiceId) REFERENCES billing.Invoices (Id) ON DELETE NO ACTION;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('billing.Payments') AND name = 'ShipmentId')
BEGIN
    ALTER TABLE billing.Payments ADD ShipmentId INT NULL;
    ALTER TABLE billing.Payments ADD CONSTRAINT FK_Payments_Shipments FOREIGN KEY (ShipmentId) REFERENCES ops.Shipments (Id) ON DELETE NO ACTION;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Payments_OneTarget')
    ALTER TABLE billing.Payments ADD CONSTRAINT CK_Payments_OneTarget CHECK (
        (InvoiceId IS NOT NULL AND ShipmentId IS NULL) OR (InvoiceId IS NULL AND ShipmentId IS NOT NULL)
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payments_ShipmentId' AND object_id = OBJECT_ID('billing.Payments'))
    CREATE NONCLUSTERED INDEX IX_Payments_ShipmentId ON billing.Payments (ShipmentId);
GO

-- ========== Consignment note numbering ==========

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.ConsignmentNoteNumberFormats') AND type = 'U')
BEGIN
    CREATE TABLE ops.ConsignmentNoteNumberFormats
    (
        Id               INT IDENTITY(1,1) NOT NULL,
        -- NULL = the global fallback used by any branch without its own row.
        BranchId         INT               NULL,
        FormatTemplate   NVARCHAR(100)     NOT NULL CONSTRAINT DF_CnNumberFormats_Template DEFAULT '{BRANCH}/{FY}/{SEQ}',
        SequencePadding  INT               NOT NULL CONSTRAINT DF_CnNumberFormats_Padding DEFAULT 5,
        CreatedAt        DATETIME2(3)      NOT NULL CONSTRAINT DF_CnNumberFormats_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy        NVARCHAR(256)     NULL,
        ModifiedAt       DATETIME2(3)      NULL,
        ModifiedBy       NVARCHAR(256)     NULL,
        IsDeleted        BIT               NOT NULL CONSTRAINT DF_CnNumberFormats_IsDeleted DEFAULT 0,
        CONSTRAINT PK_ConsignmentNoteNumberFormats PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_CnNumberFormats_Branches FOREIGN KEY (BranchId) REFERENCES lookup.Branches (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_CnNumberFormats_Padding CHECK (SequencePadding BETWEEN 1 AND 10)
    );
END
GO

-- At most one row per branch, and at most one global (NULL) default.
-- Filtered indexes - see the QUOTED_IDENTIFIER comment above.
SET QUOTED_IDENTIFIER ON;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_CnNumberFormats_Branch' AND object_id = OBJECT_ID('ops.ConsignmentNoteNumberFormats'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_CnNumberFormats_Branch ON ops.ConsignmentNoteNumberFormats (BranchId) WHERE BranchId IS NOT NULL AND IsDeleted = 0;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_CnNumberFormats_Global' AND object_id = OBJECT_ID('ops.ConsignmentNoteNumberFormats'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_CnNumberFormats_Global ON ops.ConsignmentNoteNumberFormats (IsDeleted) WHERE BranchId IS NULL AND IsDeleted = 0;
GO

-- Pure atomic counter - never read by the UI directly, only incremented by
-- ops.usp_InsertShipment (see 026_...procs.sql) inside the same transaction
-- as the shipment/CN insert, so a rolled-back save never leaves a gap.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.ConsignmentNoteSequences') AND type = 'U')
BEGIN
    CREATE TABLE ops.ConsignmentNoteSequences
    (
        Id                 INT IDENTITY(1,1) NOT NULL,
        BranchId           INT               NOT NULL,
        FinancialYearCode  CHAR(4)           NOT NULL,
        LastSequence       INT               NOT NULL CONSTRAINT DF_CnSequences_LastSequence DEFAULT 0,
        CONSTRAINT PK_ConsignmentNoteSequences PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_CnSequences_Branches FOREIGN KEY (BranchId) REFERENCES lookup.Branches (Id) ON DELETE NO ACTION,
        CONSTRAINT UQ_CnSequences_BranchYear UNIQUE (BranchId, FinancialYearCode)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.ConsignmentNotes') AND type = 'U')
BEGIN
    CREATE TABLE ops.ConsignmentNotes
    (
        Id               INT IDENTITY(1,1) NOT NULL,
        ShipmentId       INT               NOT NULL,
        CnNumber         NVARCHAR(50)      NOT NULL,
        BranchId         INT               NOT NULL,
        CnDate           DATE              NOT NULL CONSTRAINT DF_ConsignmentNotes_CnDate DEFAULT (CAST(SYSUTCDATETIME() AS DATE)),
        Packages         INT               NULL,
        ActualWeightKg   DECIMAL(18,2)     NULL,
        ChargedWeightKg  DECIMAL(18,2)     NULL,
        DeclaredValue    DECIMAL(18,2)     NULL,
        -- Populated once freight calculation lands (Phase 3 / F4) - left
        -- nullable now, deliberately not computed in this phase.
        FreightAmount    DECIMAL(18,2)     NULL,
        Remarks          NVARCHAR(500)     NULL,
        -- Reuses the existing Shipment status lifecycle (category
        -- 'Shipment': Booked/InTransit/Delivered/Cancelled) rather than
        -- seeding a duplicate set of rows for the same four states.
        StatusId         INT               NOT NULL,
        CancelReason     NVARCHAR(500)     NULL,
        CancelledAt      DATETIME2(3)      NULL,
        CancelledBy      NVARCHAR(256)     NULL,
        CreatedAt        DATETIME2(3)      NOT NULL CONSTRAINT DF_ConsignmentNotes_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy        NVARCHAR(256)     NULL,
        ModifiedAt       DATETIME2(3)      NULL,
        ModifiedBy       NVARCHAR(256)     NULL,
        -- Never hard-deleted (financial/legal record) - Cancelled status +
        -- CancelReason is the removal mechanism, not IsDeleted. Column kept
        -- only for schema-wide consistency; no proc ever sets it to 1.
        IsDeleted        BIT               NOT NULL CONSTRAINT DF_ConsignmentNotes_IsDeleted DEFAULT 0,
        CONSTRAINT PK_ConsignmentNotes PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_ConsignmentNotes_ShipmentId UNIQUE (ShipmentId),
        CONSTRAINT UQ_ConsignmentNotes_CnNumber UNIQUE (CnNumber),
        CONSTRAINT FK_ConsignmentNotes_Shipments FOREIGN KEY (ShipmentId) REFERENCES ops.Shipments (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_ConsignmentNotes_Branches FOREIGN KEY (BranchId) REFERENCES lookup.Branches (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_ConsignmentNotes_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_ConsignmentNotes_CancelReason CHECK (CancelReason IS NULL OR (CancelledAt IS NOT NULL AND CancelledBy IS NOT NULL))
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ConsignmentNotes_BranchId' AND object_id = OBJECT_ID('ops.ConsignmentNotes'))
    CREATE NONCLUSTERED INDEX IX_ConsignmentNotes_BranchId ON ops.ConsignmentNotes (BranchId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ConsignmentNotes_StatusId' AND object_id = OBJECT_ID('ops.ConsignmentNotes'))
    CREATE NONCLUSTERED INDEX IX_ConsignmentNotes_StatusId ON ops.ConsignmentNotes (StatusId);
GO
