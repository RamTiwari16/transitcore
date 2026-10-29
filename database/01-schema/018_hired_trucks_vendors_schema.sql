/*
  Purpose:      Phase 4 (F5) of the freight-carrier feature set. Adds
                billing.Vendors (truck owner/broker master data), lets
                ops.Trips represent a Hired (market) truck trip alongside
                the existing Own (fleet) trips, and adds the vendor cost
                ledger (advances, deductions), formal billing (VendorBills/
                VendorPayments), and the data trip profit needs.
  Author:       TransitCore rebuild
  Date:         2026-10-05
  Dependencies: 007_billing_customers_schema.sql (billing schema),
                008_ops_routes_trips_shipments_schema.sql (ops.Trips)

  Breaking change, pre-approved during the original Phase 1 audit:
  ops.Trips.VehicleId/DriverId become NULLable (a Hired trip has no fleet
  vehicle or driver - "hired trucks are not in our fleet"). This is a
  constraint LOOSENING, not a tightening - every existing row already has
  both columns populated, so no backfill risk the way F1's Branches.Code
  NOT NULL tightening had. The real risk is every EXISTING query that
  INNER JOINs Trips to fleet.Vehicles/fleet.Drivers assuming they always
  exist - audited and fixed in 029_hired_trucks_vendors_procs.sql (full
  list: usp_GetTrips, usp_GetTripById, usp_CheckTripConflicts,
  usp_GetTripCapacityCheck, dbo.usp_GlobalSearch's Trip branch, and
  fleet.usp_GetFleetUtilisationTrend, which doesn't join Vehicles/Drivers at
  all but would silently fold a hired trip's hours into fleet utilisation%
  without an added OwnershipType filter).
*/
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== billing.Vendors ==========

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.Vendors') AND type = 'U')
BEGIN
    CREATE TABLE billing.Vendors
    (
        Id               INT IDENTITY(1,1) NOT NULL,
        Code             NVARCHAR(50)      NOT NULL,
        Name             NVARCHAR(200)     NOT NULL,
        ContactName      NVARCHAR(200)     NULL,
        ContactPhone     NVARCHAR(30)      NULL,
        ContactEmail     NVARCHAR(256)     NULL,
        Address          NVARCHAR(300)     NULL,
        BankAccountNo    NVARCHAR(50)      NULL,
        BankIfscCode     NVARCHAR(20)      NULL,
        PanNo            NVARCHAR(20)      NULL,
        GstinNo          NVARCHAR(20)      NULL,
        IsActive         BIT               NOT NULL CONSTRAINT DF_Vendors_IsActive DEFAULT 1,
        CreatedAt        DATETIME2(3)      NOT NULL CONSTRAINT DF_Vendors_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy        NVARCHAR(256)     NULL,
        ModifiedAt       DATETIME2(3)      NULL,
        ModifiedBy       NVARCHAR(256)     NULL,
        IsDeleted        BIT               NOT NULL CONSTRAINT DF_Vendors_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Vendors PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Vendors_Code UNIQUE (Code)
    );
END
GO

-- ========== ops.Trips: OwnershipType / hired-truck fields ==========

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ops.Trips') AND name = 'OwnershipType')
BEGIN
    ALTER TABLE ops.Trips ADD
        OwnershipType      NVARCHAR(10)  NOT NULL CONSTRAINT DF_Trips_OwnershipType DEFAULT 'Own',
        VendorId           INT           NULL,
        HiredVehicleNo     NVARCHAR(30)  NULL,
        HiredDriverName    NVARCHAR(200) NULL,
        HiredDriverPhone   NVARCHAR(30)  NULL,
        VendorFreightAmount DECIMAL(18,2) NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Trips_Vendors')
    ALTER TABLE ops.Trips ADD CONSTRAINT FK_Trips_Vendors FOREIGN KEY (VendorId) REFERENCES billing.Vendors (Id) ON DELETE NO ACTION;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Trips_OwnershipType')
    ALTER TABLE ops.Trips ADD CONSTRAINT CK_Trips_OwnershipType CHECK (OwnershipType IN ('Own', 'Hired'));
GO

-- Loosen VehicleId/DriverId to nullable - every existing row already has
-- both populated (see header comment), so this is safe on data already in
-- the table; only new Hired-trip inserts will actually leave them NULL.
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ops.Trips') AND name = 'VehicleId' AND is_nullable = 0)
BEGIN
    ALTER TABLE ops.Trips DROP CONSTRAINT FK_Trips_Vehicles;
    ALTER TABLE ops.Trips ALTER COLUMN VehicleId INT NULL;
    ALTER TABLE ops.Trips ADD CONSTRAINT FK_Trips_Vehicles FOREIGN KEY (VehicleId) REFERENCES fleet.Vehicles (Id) ON DELETE NO ACTION;
END
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ops.Trips') AND name = 'DriverId' AND is_nullable = 0)
BEGIN
    ALTER TABLE ops.Trips DROP CONSTRAINT FK_Trips_Drivers;
    ALTER TABLE ops.Trips ALTER COLUMN DriverId INT NULL;
    ALTER TABLE ops.Trips ADD CONSTRAINT FK_Trips_Drivers FOREIGN KEY (DriverId) REFERENCES fleet.Drivers (Id) ON DELETE NO ACTION;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Trips_OwnershipConsistency')
    ALTER TABLE ops.Trips ADD CONSTRAINT CK_Trips_OwnershipConsistency CHECK (
        (OwnershipType = 'Own' AND VehicleId IS NOT NULL AND DriverId IS NOT NULL AND VendorId IS NULL AND HiredVehicleNo IS NULL) OR
        (OwnershipType = 'Hired' AND VehicleId IS NULL AND DriverId IS NULL AND VendorId IS NOT NULL AND HiredVehicleNo IS NOT NULL)
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Trips_VendorId' AND object_id = OBJECT_ID('ops.Trips'))
    CREATE NONCLUSTERED INDEX IX_Trips_VendorId ON ops.Trips (VendorId);
GO

-- ========== ops.VendorAdvances / ops.VendorDeductions ==========
-- Live in ops (not billing) to match the existing ops.TripExpenses/
-- ops.TripAdvances precedent for trip-scoped cost tracking; the FORMAL
-- billing documents (VendorBills/VendorPayments below) live in billing,
-- matching billing.Invoices/Payments.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.VendorAdvances') AND type = 'U')
BEGIN
    CREATE TABLE ops.VendorAdvances
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        TripId       INT               NOT NULL,
        VendorId     INT               NOT NULL,
        Amount       DECIMAL(18,2)     NOT NULL,
        AdvanceDate  DATE              NOT NULL,
        Remarks      NVARCHAR(300)     NULL,
        CreatedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_VendorAdvances_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(256)     NULL,
        ModifiedAt   DATETIME2(3)      NULL,
        ModifiedBy   NVARCHAR(256)     NULL,
        IsDeleted    BIT               NOT NULL CONSTRAINT DF_VendorAdvances_IsDeleted DEFAULT 0,
        CONSTRAINT PK_VendorAdvances PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_VendorAdvances_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_VendorAdvances_Vendors FOREIGN KEY (VendorId) REFERENCES billing.Vendors (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_VendorAdvances_Amount CHECK (Amount > 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VendorAdvances_TripId' AND object_id = OBJECT_ID('ops.VendorAdvances'))
    CREATE NONCLUSTERED INDEX IX_VendorAdvances_TripId ON ops.VendorAdvances (TripId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.VendorDeductions') AND type = 'U')
BEGIN
    CREATE TABLE ops.VendorDeductions
    (
        Id             INT IDENTITY(1,1) NOT NULL,
        TripId         INT               NOT NULL,
        VendorId       INT               NOT NULL,
        Amount         DECIMAL(18,2)     NOT NULL,
        Reason         NVARCHAR(300)     NOT NULL,
        DeductionDate  DATE              NOT NULL,
        CreatedAt      DATETIME2(3)      NOT NULL CONSTRAINT DF_VendorDeductions_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy      NVARCHAR(256)     NULL,
        ModifiedAt     DATETIME2(3)      NULL,
        ModifiedBy     NVARCHAR(256)     NULL,
        IsDeleted      BIT               NOT NULL CONSTRAINT DF_VendorDeductions_IsDeleted DEFAULT 0,
        CONSTRAINT PK_VendorDeductions PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_VendorDeductions_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_VendorDeductions_Vendors FOREIGN KEY (VendorId) REFERENCES billing.Vendors (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_VendorDeductions_Amount CHECK (Amount > 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VendorDeductions_TripId' AND object_id = OBJECT_ID('ops.VendorDeductions'))
    CREATE NONCLUSTERED INDEX IX_VendorDeductions_TripId ON ops.VendorDeductions (TripId);
GO

-- ========== billing.VendorBills / billing.VendorPayments ==========
-- Deliberately parallel billing.Invoices/billing.Payments - same soft-delete-
-- only, never-hard-delete-a-financial-record convention.

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.VendorBills') AND type = 'U')
BEGIN
    CREATE TABLE billing.VendorBills
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        VendorId     INT               NOT NULL,
        TripId       INT               NOT NULL,
        BillNo       NVARCHAR(50)      NOT NULL,
        BillDate     DATE              NOT NULL,
        DueDate      DATE              NOT NULL,
        Amount       DECIMAL(18,2)     NOT NULL,
        StatusId     INT               NOT NULL,
        CreatedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_VendorBills_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(256)     NULL,
        ModifiedAt   DATETIME2(3)      NULL,
        ModifiedBy   NVARCHAR(256)     NULL,
        IsDeleted    BIT               NOT NULL CONSTRAINT DF_VendorBills_IsDeleted DEFAULT 0,
        CONSTRAINT PK_VendorBills PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_VendorBills_BillNo UNIQUE (BillNo),
        -- One bill per hired trip - the trip's agreed VendorFreightAmount
        -- (less deductions) is the whole of what's billed for it.
        CONSTRAINT UQ_VendorBills_TripId UNIQUE (TripId),
        CONSTRAINT FK_VendorBills_Vendors FOREIGN KEY (VendorId) REFERENCES billing.Vendors (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_VendorBills_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_VendorBills_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_VendorBills_DueDate CHECK (DueDate >= BillDate),
        CONSTRAINT CK_VendorBills_Amount CHECK (Amount >= 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VendorBills_VendorId' AND object_id = OBJECT_ID('billing.VendorBills'))
    CREATE NONCLUSTERED INDEX IX_VendorBills_VendorId ON billing.VendorBills (VendorId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.VendorPayments') AND type = 'U')
BEGIN
    CREATE TABLE billing.VendorPayments
    (
        Id            INT IDENTITY(1,1) NOT NULL,
        VendorBillId  INT               NOT NULL,
        PaymentDate   DATE              NOT NULL,
        Amount        DECIMAL(18,2)     NOT NULL,
        Method        NVARCHAR(50)      NOT NULL,
        ReferenceNo   NVARCHAR(100)     NULL,
        CreatedAt     DATETIME2(3)      NOT NULL CONSTRAINT DF_VendorPayments_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy     NVARCHAR(256)     NULL,
        ModifiedAt    DATETIME2(3)      NULL,
        ModifiedBy    NVARCHAR(256)     NULL,
        IsDeleted     BIT               NOT NULL CONSTRAINT DF_VendorPayments_IsDeleted DEFAULT 0,
        CONSTRAINT PK_VendorPayments PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_VendorPayments_VendorBills FOREIGN KEY (VendorBillId) REFERENCES billing.VendorBills (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_VendorPayments_Amount CHECK (Amount > 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VendorPayments_VendorBillId' AND object_id = OBJECT_ID('billing.VendorPayments'))
    CREATE NONCLUSTERED INDEX IX_VendorPayments_VendorBillId ON billing.VendorPayments (VendorBillId);
GO
