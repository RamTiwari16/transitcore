/*
  Purpose:      Phase 5 (F6 + F7) of the freight-carrier feature set.
                F6: loaded/empty km on ops.Trips for empty-running% reporting
                and a "vehicles becoming available" report (both are pure
                read procs in 030_..._procs.sql - no new tables needed for
                F6 itself).
                F7: per-shipment-item delivery reconciliation (delivered/
                short/damaged qty + photos, mirroring ops.ProofOfDelivery's
                parent-row-plus-photos shape exactly) and billing.Claims,
                including a settled claim actually reducing what's still
                owed - either on the related customer Invoice
                (DeductionAmount, a new parallel to how Payments already
                reduce it) or, via VendorRecovery, as a new
                ops.VendorDeductions row against the trip's vendor (F5's
                existing mechanism, reused as-is - no new schema needed for
                that path at all).
  Author:       TransitCore rebuild
  Date:         2026-10-09
  Dependencies: 008_ops_routes_trips_shipments_schema.sql (ops.Trips,
                ops.ShipmentItems), 009_billing_invoicing_schema.sql
                (billing.Invoices), 018_hired_trucks_vendors_schema.sql
                (ops.VendorDeductions - F7's VendorRecovery path inserts
                into this existing table, doesn't need its own)
*/
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== F6: ops.Trips - loaded / empty km ==========
-- Deliberately a separate, focused update path (see usp_UpdateTripKm in
-- 030_..._procs.sql) rather than folded into usp_UpdateTrip - actual run km
-- is dispatch-workflow data entered once a trip is done, the same "not this
-- form" reasoning usp_UpdateTrip's own header comment already gives for why
-- ActualDeparture/ActualArrival aren't in it either.

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ops.Trips') AND name = 'LoadedKm')
    ALTER TABLE ops.Trips ADD LoadedKm DECIMAL(18,2) NULL, EmptyKm DECIMAL(18,2) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Trips_Km')
    ALTER TABLE ops.Trips ADD CONSTRAINT CK_Trips_Km CHECK (
        (LoadedKm IS NULL OR LoadedKm >= 0) AND (EmptyKm IS NULL OR EmptyKm >= 0)
    );
GO

-- ========== F7: per-item delivery reconciliation ==========

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.ShipmentItemDeliveries') AND type = 'U')
BEGIN
    CREATE TABLE ops.ShipmentItemDeliveries
    (
        Id               INT IDENTITY(1,1) NOT NULL,
        ShipmentItemId   INT               NOT NULL,
        DeliveredQty     DECIMAL(18,2)     NOT NULL,
        ShortQty         DECIMAL(18,2)     NOT NULL CONSTRAINT DF_ShipmentItemDeliveries_ShortQty DEFAULT 0,
        DamagedQty       DECIMAL(18,2)     NOT NULL CONSTRAINT DF_ShipmentItemDeliveries_DamagedQty DEFAULT 0,
        Remarks          NVARCHAR(500)     NULL,
        CreatedAt        DATETIME2(3)      NOT NULL CONSTRAINT DF_ShipmentItemDeliveries_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy        NVARCHAR(256)     NULL,
        ModifiedAt       DATETIME2(3)      NULL,
        ModifiedBy       NVARCHAR(256)     NULL,
        IsDeleted        BIT               NOT NULL CONSTRAINT DF_ShipmentItemDeliveries_IsDeleted DEFAULT 0,
        CONSTRAINT PK_ShipmentItemDeliveries PRIMARY KEY CLUSTERED (Id),
        -- One reconciliation record per item, same "one parent event row"
        -- shape as ops.ProofOfDelivery's UQ_ProofOfDelivery_TripId.
        CONSTRAINT UQ_ShipmentItemDeliveries_ItemId UNIQUE (ShipmentItemId),
        CONSTRAINT FK_ShipmentItemDeliveries_Items FOREIGN KEY (ShipmentItemId) REFERENCES ops.ShipmentItems (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_ShipmentItemDeliveries_Qty CHECK (DeliveredQty >= 0 AND ShortQty >= 0 AND DamagedQty >= 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.ShipmentItemDeliveryPhotos') AND type = 'U')
BEGIN
    CREATE TABLE ops.ShipmentItemDeliveryPhotos
    (
        Id                        INT IDENTITY(1,1) NOT NULL,
        ShipmentItemDeliveryId    INT               NOT NULL,
        FilePath                  NVARCHAR(400)     NOT NULL,
        UploadedAt                DATETIME2(3)      NOT NULL CONSTRAINT DF_ShipmentItemDeliveryPhotos_UploadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_ShipmentItemDeliveryPhotos PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_ShipmentItemDeliveryPhotos_Delivery FOREIGN KEY (ShipmentItemDeliveryId) REFERENCES ops.ShipmentItemDeliveries (Id) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ShipmentItemDeliveryPhotos_DeliveryId' AND object_id = OBJECT_ID('ops.ShipmentItemDeliveryPhotos'))
    CREATE NONCLUSTERED INDEX IX_ShipmentItemDeliveryPhotos_DeliveryId ON ops.ShipmentItemDeliveryPhotos (ShipmentItemDeliveryId);
GO

-- ========== F7: billing.Claims ==========

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.Claims') AND type = 'U')
BEGIN
    CREATE TABLE billing.Claims
    (
        Id                INT IDENTITY(1,1) NOT NULL,
        ShipmentId        INT               NOT NULL,
        ClaimantName      NVARCHAR(200)     NOT NULL,
        ClaimantPhone     NVARCHAR(30)      NULL,
        AmountClaimed     DECIMAL(18,2)     NOT NULL,
        StatusId          INT               NOT NULL,
        SettledAmount     DECIMAL(18,2)     NULL,
        SettlementMethod  NVARCHAR(30)      NULL,
        Notes             NVARCHAR(500)     NULL,
        CreatedAt         DATETIME2(3)      NOT NULL CONSTRAINT DF_Claims_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy         NVARCHAR(256)     NULL,
        ModifiedAt        DATETIME2(3)      NULL,
        ModifiedBy        NVARCHAR(256)     NULL,
        IsDeleted         BIT               NOT NULL CONSTRAINT DF_Claims_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Claims PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Claims_Shipments FOREIGN KEY (ShipmentId) REFERENCES ops.Shipments (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Claims_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_Claims_AmountClaimed CHECK (AmountClaimed >= 0),
        CONSTRAINT CK_Claims_SettledAmount CHECK (SettledAmount IS NULL OR SettledAmount >= 0),
        CONSTRAINT CK_Claims_SettlementMethod CHECK (SettlementMethod IS NULL OR SettlementMethod IN
            ('InvoiceDeduction', 'CreditNote', 'Insurance', 'DriverRecovery', 'VendorRecovery'))
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Claims_ShipmentId' AND object_id = OBJECT_ID('billing.Claims'))
    CREATE NONCLUSTERED INDEX IX_Claims_ShipmentId ON billing.Claims (ShipmentId);
GO

-- Status changes are audited - mirrors ops.TripStatusHistory exactly.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.ClaimStatusHistory') AND type = 'U')
BEGIN
    CREATE TABLE billing.ClaimStatusHistory
    (
        Id         INT IDENTITY(1,1) NOT NULL,
        ClaimId    INT               NOT NULL,
        StatusId   INT               NOT NULL,
        ChangedAt  DATETIME2(3)      NOT NULL CONSTRAINT DF_ClaimStatusHistory_ChangedAt DEFAULT SYSUTCDATETIME(),
        Notes      NVARCHAR(500)     NULL,
        CreatedBy  NVARCHAR(256)     NULL,
        CONSTRAINT PK_ClaimStatusHistory PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_ClaimStatusHistory_Claims FOREIGN KEY (ClaimId) REFERENCES billing.Claims (Id) ON DELETE CASCADE,
        CONSTRAINT FK_ClaimStatusHistory_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ClaimStatusHistory_ClaimId' AND object_id = OBJECT_ID('billing.ClaimStatusHistory'))
    CREATE NONCLUSTERED INDEX IX_ClaimStatusHistory_ClaimId ON billing.ClaimStatusHistory (ClaimId);
GO

-- ========== F7: billing.Invoices - deduction from a settled claim ==========
-- Parallels how Payments already reduce what's owed (TotalAmount - SUM(Payments))
-- via a SUM elsewhere - here it's a single running total on the invoice
-- itself instead, since a deduction isn't a discrete transaction history
-- staff needs to browse the way payments are, just a running adjustment.
-- Every existing query that computes an invoice balance needs this term
-- added - see 030_..._procs.sql's header comment for the full list.

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('billing.Invoices') AND name = 'DeductionAmount')
    ALTER TABLE billing.Invoices ADD DeductionAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_Invoices_DeductionAmount DEFAULT 0;
GO
