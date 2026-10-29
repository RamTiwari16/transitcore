/*
  Purpose:      Phase 3 (F4) of the freight-carrier feature set. Extends
                billing.RateCards with a rate Basis (PerTrip/PerTon/PerKm/
                PerPackage), a minimum chargeable weight, and optional
                loading/unloading/detention/halting rates. Adds
                billing.ShipmentCharges (Freight/Loading/Unloading/
                Detention/Halting/Other lines per shipment, with an audited
                override-with-reason path) and ops.TripStopVisits (arrival/
                departure time PER STOP on a trip, decoupled from any one
                shipment's load/unload event - see design note below).
                Links billing.InvoiceLines back to the specific
                ShipmentCharge it billed.
  Author:       TransitCore rebuild
  Date:         2026-10-02
  Dependencies: 009_billing_invoicing_schema.sql (billing.RateCards,
                billing.InvoiceLines), 008_ops_routes_trips_shipments_schema.sql
                (ops.Trips), 016_capacity_volume_trip_stop_shipments_schema.sql
                (ops.TripStopShipments - same Origin/IntermediateStop/
                Destination StopType convention)

  Design note - detention time lives on the STOP, not the shipment: a
  vehicle's dwell time at a stop is one physical fact regardless of how many
  shipments load/unload there, so ops.TripStopVisits is one row per (Trip,
  Stop) - not per (Trip, Stop, Shipment) the way ops.TripStopShipments is.
  Turning a stop's dwell time into a specific shipment's Detention
  ShipmentCharge is a deliberate MANUAL step (staff picks the shipment(s)
  and amount, pre-filled from the rate card's rate/free-hours as a
  suggestion) rather than an automatic split across every shipment present -
  auto-splitting would silently bake in a specific business assumption
  (even split? full charge to each? to whichever was there longest?) with
  no clearly-right default and real billing-dispute risk if wrong.
*/
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== billing.RateCards: basis + minimum weight + extra rates ==========

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('billing.RateCards') AND name = 'Basis')
BEGIN
    ALTER TABLE billing.RateCards ADD
        -- Existing RatePerKg/RatePerKm columns are kept as-is (never
        -- populated into a real calculation before this phase - confirmed
        -- by grep, "most specific rate card wins" was a comment describing
        -- intended-but-never-written C# logic). RatePerKm becomes the
        -- active rate for the PerKm basis; RatePerKg is left in place,
        -- unused going forward, rather than repurposed or dropped.
        Basis                   NVARCHAR(20)  NOT NULL CONSTRAINT DF_RateCards_Basis DEFAULT 'PerKm',
        RatePerTrip              DECIMAL(18,2) NULL,
        RatePerTon               DECIMAL(18,2) NULL,
        RatePerPackage           DECIMAL(18,2) NULL,
        MinimumChargeableWeightKg DECIMAL(18,2) NULL,
        LoadingRatePerEvent      DECIMAL(18,2) NULL,
        UnloadingRatePerEvent    DECIMAL(18,2) NULL,
        DetentionFreeHours       DECIMAL(18,2) NULL,
        DetentionRatePerHour     DECIMAL(18,2) NULL,
        HaltingRatePerDay        DECIMAL(18,2) NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_RateCards_Basis')
    ALTER TABLE billing.RateCards ADD CONSTRAINT CK_RateCards_Basis CHECK (Basis IN ('PerTrip', 'PerTon', 'PerKm', 'PerPackage'));
GO

-- ========== billing.ShipmentCharges ==========

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.ShipmentCharges') AND type = 'U')
BEGIN
    CREATE TABLE billing.ShipmentCharges
    (
        Id              INT IDENTITY(1,1) NOT NULL,
        ShipmentId      INT               NOT NULL,
        ChargeType      NVARCHAR(20)      NOT NULL,
        Amount          DECIMAL(18,2)     NOT NULL,
        -- Freeform note for any charge type, required (enforced below) when
        -- ChargeType = 'Other' and whenever IsOverridden = 1 - same
        -- audited-override spirit as F1/F2's cancel-with-reason pattern.
        Description     NVARCHAR(300)     NULL,
        IsOverridden    BIT               NOT NULL CONSTRAINT DF_ShipmentCharges_IsOverridden DEFAULT 0,
        OverrideReason  NVARCHAR(500)     NULL,
        CreatedAt       DATETIME2(3)      NOT NULL CONSTRAINT DF_ShipmentCharges_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy       NVARCHAR(256)     NULL,
        ModifiedAt      DATETIME2(3)      NULL,
        ModifiedBy      NVARCHAR(256)     NULL,
        IsDeleted       BIT               NOT NULL CONSTRAINT DF_ShipmentCharges_IsDeleted DEFAULT 0,
        CONSTRAINT PK_ShipmentCharges PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_ShipmentCharges_Shipments FOREIGN KEY (ShipmentId) REFERENCES ops.Shipments (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_ShipmentCharges_ChargeType CHECK (ChargeType IN ('Freight', 'Loading', 'Unloading', 'Detention', 'Halting', 'Other')),
        CONSTRAINT CK_ShipmentCharges_Amount CHECK (Amount >= 0),
        CONSTRAINT CK_ShipmentCharges_OverrideReason CHECK (IsOverridden = 0 OR OverrideReason IS NOT NULL),
        CONSTRAINT CK_ShipmentCharges_OtherDescription CHECK (ChargeType <> 'Other' OR Description IS NOT NULL)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ShipmentCharges_ShipmentId' AND object_id = OBJECT_ID('billing.ShipmentCharges'))
    CREATE NONCLUSTERED INDEX IX_ShipmentCharges_ShipmentId ON billing.ShipmentCharges (ShipmentId);
GO

-- ========== ops.TripStopVisits: arrival/departure per stop ==========

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.TripStopVisits') AND type = 'U')
BEGIN
    CREATE TABLE ops.TripStopVisits
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        TripId       INT               NOT NULL,
        StopType     NVARCHAR(20)      NOT NULL,
        RouteStopId  INT               NULL,
        ArrivedAt    DATETIME2(3)      NULL,
        DepartedAt   DATETIME2(3)      NULL,
        CreatedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_TripStopVisits_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(256)     NULL,
        ModifiedAt   DATETIME2(3)      NULL,
        ModifiedBy   NVARCHAR(256)     NULL,
        IsDeleted    BIT               NOT NULL CONSTRAINT DF_TripStopVisits_IsDeleted DEFAULT 0,
        CONSTRAINT PK_TripStopVisits PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_TripStopVisits_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_TripStopVisits_RouteStops FOREIGN KEY (RouteStopId) REFERENCES ops.RouteStops (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_TripStopVisits_StopType CHECK (StopType IN ('Origin', 'IntermediateStop', 'Destination')),
        CONSTRAINT CK_TripStopVisits_RouteStopConsistency CHECK (
            (StopType = 'IntermediateStop' AND RouteStopId IS NOT NULL) OR
            (StopType <> 'IntermediateStop' AND RouteStopId IS NULL)
        ),
        CONSTRAINT CK_TripStopVisits_DepartAfterArrive CHECK (DepartedAt IS NULL OR ArrivedAt IS NULL OR DepartedAt >= ArrivedAt),
        -- One visit record per physical stop per trip - NULLs in RouteStopId
        -- for Origin/Destination don't collide since StopType still
        -- differs between those two rows.
        CONSTRAINT UQ_TripStopVisits_Stop UNIQUE (TripId, StopType, RouteStopId)
    );
END
GO

-- ========== billing.InvoiceLines: trace back to the ShipmentCharge billed ==========

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('billing.InvoiceLines') AND name = 'ShipmentChargeId')
BEGIN
    ALTER TABLE billing.InvoiceLines ADD ShipmentChargeId INT NULL;
    ALTER TABLE billing.InvoiceLines ADD CONSTRAINT FK_InvoiceLines_ShipmentCharges FOREIGN KEY (ShipmentChargeId) REFERENCES billing.ShipmentCharges (Id) ON DELETE NO ACTION;
END
GO
