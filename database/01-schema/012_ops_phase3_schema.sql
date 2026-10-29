/*
  Purpose:      Phase 3 (Ops depth) new tables - trip expenses/advances (cost
                tracking, not full revenue P&L: this schema has no clean way
                to attribute invoice revenue to a single trip yet, so this is
                a cost/settlement view - "advance given vs expenses spent" -
                which also directly feeds the later driver-settlement
                feature), proof of delivery + photos, trip document uploads,
                and trip incident/delay reports. Also adds a tracking number
                to Shipments for the public tracking page.

                ops.RouteStops (multi-stop legs) and ops.TripStatusHistory
                already existed unused from the original schema - no new
                table needed for either.
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 008_ops_routes_trips_shipments_schema.sql
*/
SET NOCOUNT ON;
GO
-- Required for the filtered unique index below (CREATE INDEX ... WHERE ...) -
-- SQL Server rejects filtered/indexed-view-style indexes under the default
-- QUOTED_IDENTIFIER OFF session setting some clients connect with.
SET QUOTED_IDENTIFIER ON;
GO

-- ---------- Shipment tracking number ----------

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('ops.Shipments') AND name = 'TrackingNo')
BEGIN
    ALTER TABLE ops.Shipments ADD TrackingNo NVARCHAR(30) NULL;
END
GO

-- Backfill existing rows (new inserts get one from usp_InsertShipment).
UPDATE ops.Shipments
SET TrackingNo = 'TRK' + RIGHT('000000' + CAST(Id AS VARCHAR(6)), 6)
WHERE TrackingNo IS NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UQ_Shipments_TrackingNo' AND object_id = OBJECT_ID('ops.Shipments'))
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Shipments_TrackingNo ON ops.Shipments (TrackingNo) WHERE TrackingNo IS NOT NULL;
GO

-- ---------- Trip expenses / advances (cost tracking + driver settlement input) ----------

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.TripExpenses') AND type = 'U')
BEGIN
    CREATE TABLE ops.TripExpenses
    (
        Id            INT IDENTITY(1,1) NOT NULL,
        TripId        INT               NOT NULL,
        ExpenseType   NVARCHAR(50)      NOT NULL,
        Amount        DECIMAL(18,2)     NOT NULL,
        ExpenseDate   DATE              NOT NULL,
        Notes         NVARCHAR(500)     NULL,
        CreatedAt     DATETIME2(3)      NOT NULL CONSTRAINT DF_TripExpenses_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy     NVARCHAR(256)     NULL,
        ModifiedAt    DATETIME2(3)      NULL,
        ModifiedBy    NVARCHAR(256)     NULL,
        IsDeleted     BIT               NOT NULL CONSTRAINT DF_TripExpenses_IsDeleted DEFAULT 0,
        CONSTRAINT PK_TripExpenses PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_TripExpenses_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE CASCADE,
        CONSTRAINT CK_TripExpenses_Amount CHECK (Amount >= 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TripExpenses_TripId' AND object_id = OBJECT_ID('ops.TripExpenses'))
    CREATE NONCLUSTERED INDEX IX_TripExpenses_TripId ON ops.TripExpenses (TripId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.TripAdvances') AND type = 'U')
BEGIN
    CREATE TABLE ops.TripAdvances
    (
        Id            INT IDENTITY(1,1) NOT NULL,
        TripId        INT               NOT NULL,
        Amount        DECIMAL(18,2)     NOT NULL,
        AdvanceDate   DATE              NOT NULL,
        Notes         NVARCHAR(500)     NULL,
        CreatedAt     DATETIME2(3)      NOT NULL CONSTRAINT DF_TripAdvances_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy     NVARCHAR(256)     NULL,
        ModifiedAt    DATETIME2(3)      NULL,
        ModifiedBy    NVARCHAR(256)     NULL,
        IsDeleted     BIT               NOT NULL CONSTRAINT DF_TripAdvances_IsDeleted DEFAULT 0,
        CONSTRAINT PK_TripAdvances PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_TripAdvances_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE CASCADE,
        CONSTRAINT CK_TripAdvances_Amount CHECK (Amount >= 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TripAdvances_TripId' AND object_id = OBJECT_ID('ops.TripAdvances'))
    CREATE NONCLUSTERED INDEX IX_TripAdvances_TripId ON ops.TripAdvances (TripId);
GO

-- ---------- Proof of delivery ----------

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.ProofOfDelivery') AND type = 'U')
BEGIN
    CREATE TABLE ops.ProofOfDelivery
    (
        Id                  INT IDENTITY(1,1) NOT NULL,
        TripId              INT               NOT NULL,
        ReceiverName        NVARCHAR(200)     NOT NULL,
        ReceiverPhone       NVARCHAR(30)      NULL,
        DeliveredAt         DATETIME2(3)      NOT NULL,
        Notes               NVARCHAR(500)     NULL,
        SignatureFilePath   NVARCHAR(400)     NULL,
        CreatedAt           DATETIME2(3)      NOT NULL CONSTRAINT DF_ProofOfDelivery_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy           NVARCHAR(256)     NULL,
        CONSTRAINT PK_ProofOfDelivery PRIMARY KEY CLUSTERED (Id),
        -- One POD per trip - a trip is delivered once; correcting a mistake
        -- means deleting and re-recording, not a second POD row.
        CONSTRAINT UQ_ProofOfDelivery_TripId UNIQUE (TripId),
        CONSTRAINT FK_ProofOfDelivery_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.ProofOfDeliveryPhotos') AND type = 'U')
BEGIN
    CREATE TABLE ops.ProofOfDeliveryPhotos
    (
        Id                  INT IDENTITY(1,1) NOT NULL,
        ProofOfDeliveryId   INT               NOT NULL,
        FilePath            NVARCHAR(400)     NOT NULL,
        UploadedAt          DATETIME2(3)      NOT NULL CONSTRAINT DF_ProofOfDeliveryPhotos_UploadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_ProofOfDeliveryPhotos PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_ProofOfDeliveryPhotos_POD FOREIGN KEY (ProofOfDeliveryId) REFERENCES ops.ProofOfDelivery (Id) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ProofOfDeliveryPhotos_PODId' AND object_id = OBJECT_ID('ops.ProofOfDeliveryPhotos'))
    CREATE NONCLUSTERED INDEX IX_ProofOfDeliveryPhotos_PODId ON ops.ProofOfDeliveryPhotos (ProofOfDeliveryId);
GO

-- ---------- Trip document uploads ----------

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.TripDocuments') AND type = 'U')
BEGIN
    CREATE TABLE ops.TripDocuments
    (
        Id            INT IDENTITY(1,1) NOT NULL,
        TripId        INT               NOT NULL,
        DocumentType  NVARCHAR(100)     NOT NULL,
        FileName      NVARCHAR(260)     NOT NULL,
        FilePath      NVARCHAR(400)     NOT NULL,
        UploadedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_TripDocuments_UploadedAt DEFAULT SYSUTCDATETIME(),
        UploadedBy    NVARCHAR(256)     NULL,
        IsDeleted     BIT               NOT NULL CONSTRAINT DF_TripDocuments_IsDeleted DEFAULT 0,
        CONSTRAINT PK_TripDocuments PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_TripDocuments_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TripDocuments_TripId' AND object_id = OBJECT_ID('ops.TripDocuments'))
    CREATE NONCLUSTERED INDEX IX_TripDocuments_TripId ON ops.TripDocuments (TripId);
GO

-- ---------- Trip incident / delay reports ----------

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.TripIncidents') AND type = 'U')
BEGIN
    CREATE TABLE ops.TripIncidents
    (
        Id            INT IDENTITY(1,1) NOT NULL,
        TripId        INT               NOT NULL,
        IncidentType  NVARCHAR(50)      NOT NULL,
        Description   NVARCHAR(1000)    NOT NULL,
        ReportedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_TripIncidents_ReportedAt DEFAULT SYSUTCDATETIME(),
        ReportedBy    NVARCHAR(256)     NULL,
        IsDeleted     BIT               NOT NULL CONSTRAINT DF_TripIncidents_IsDeleted DEFAULT 0,
        CONSTRAINT PK_TripIncidents PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_TripIncidents_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TripIncidents_TripId' AND object_id = OBJECT_ID('ops.TripIncidents'))
    CREATE NONCLUSTERED INDEX IX_TripIncidents_TripId ON ops.TripIncidents (TripId);
GO
