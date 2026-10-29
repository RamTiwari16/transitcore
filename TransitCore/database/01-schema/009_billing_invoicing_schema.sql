/*
  Purpose:      Billing domain - rate cards, invoices, invoice lines,
                payments. Financial records: no cascading deletes anywhere
                in this file, per the house rule.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 005_lookup_extended.sql, 007_billing_customers_schema.sql,
                008_ops_routes_trips_shipments_schema.sql
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.RateCards') AND type = 'U')
BEGIN
    CREATE TABLE billing.RateCards
    (
        Id                 INT IDENTITY(1,1) NOT NULL,
        CustomerId         INT               NULL,
        OriginCityId       INT               NULL,
        DestinationCityId  INT               NULL,
        RatePerKg          DECIMAL(18,2)     NOT NULL CONSTRAINT DF_RateCards_RatePerKg DEFAULT 0,
        RatePerKm          DECIMAL(18,2)     NOT NULL CONSTRAINT DF_RateCards_RatePerKm DEFAULT 0,
        EffectiveFrom      DATE              NOT NULL,
        EffectiveTo        DATE              NULL,
        CreatedAt          DATETIME2(3)      NOT NULL CONSTRAINT DF_RateCards_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy          NVARCHAR(256)     NULL,
        ModifiedAt         DATETIME2(3)      NULL,
        ModifiedBy         NVARCHAR(256)     NULL,
        IsDeleted          BIT               NOT NULL CONSTRAINT DF_RateCards_IsDeleted DEFAULT 0,
        CONSTRAINT PK_RateCards PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_RateCards_Customers FOREIGN KEY (CustomerId) REFERENCES billing.Customers (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_RateCards_OriginCity FOREIGN KEY (OriginCityId) REFERENCES lookup.Cities (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_RateCards_DestinationCity FOREIGN KEY (DestinationCityId) REFERENCES lookup.Cities (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_RateCards_EffectiveWindow CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RateCards_CustomerId' AND object_id = OBJECT_ID('billing.RateCards'))
    CREATE NONCLUSTERED INDEX IX_RateCards_CustomerId ON billing.RateCards (CustomerId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.Invoices') AND type = 'U')
BEGIN
    CREATE TABLE billing.Invoices
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        InvoiceNo    NVARCHAR(50)      NOT NULL,
        CustomerId   INT               NOT NULL,
        InvoiceDate  DATE              NOT NULL,
        DueDate      DATE              NOT NULL,
        Subtotal     DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Invoices_Subtotal DEFAULT 0,
        TaxAmount    DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Invoices_TaxAmount DEFAULT 0,
        TotalAmount  DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Invoices_TotalAmount DEFAULT 0,
        StatusId     INT               NOT NULL,
        CreatedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_Invoices_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(256)     NULL,
        ModifiedAt   DATETIME2(3)      NULL,
        ModifiedBy   NVARCHAR(256)     NULL,
        IsDeleted    BIT               NOT NULL CONSTRAINT DF_Invoices_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Invoices PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Invoices_InvoiceNo UNIQUE (InvoiceNo),
        CONSTRAINT FK_Invoices_Customers FOREIGN KEY (CustomerId) REFERENCES billing.Customers (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Invoices_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_Invoices_DueDate CHECK (DueDate >= InvoiceDate),
        CONSTRAINT CK_Invoices_Amounts CHECK (Subtotal >= 0 AND TaxAmount >= 0 AND TotalAmount >= 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Invoices_CustomerId' AND object_id = OBJECT_ID('billing.Invoices'))
    CREATE NONCLUSTERED INDEX IX_Invoices_CustomerId ON billing.Invoices (CustomerId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Invoices_StatusId' AND object_id = OBJECT_ID('billing.Invoices'))
    CREATE NONCLUSTERED INDEX IX_Invoices_StatusId ON billing.Invoices (StatusId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Invoices_InvoiceDate' AND object_id = OBJECT_ID('billing.Invoices'))
    CREATE NONCLUSTERED INDEX IX_Invoices_InvoiceDate ON billing.Invoices (InvoiceDate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.InvoiceLines') AND type = 'U')
BEGIN
    CREATE TABLE billing.InvoiceLines
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        InvoiceId    INT               NOT NULL,
        ShipmentId   INT               NULL,
        Description  NVARCHAR(300)     NOT NULL,
        Quantity     DECIMAL(18,2)     NOT NULL CONSTRAINT DF_InvoiceLines_Quantity DEFAULT 1,
        UnitPrice    DECIMAL(18,2)     NOT NULL CONSTRAINT DF_InvoiceLines_UnitPrice DEFAULT 0,
        LineTotal    DECIMAL(18,2)     NOT NULL CONSTRAINT DF_InvoiceLines_LineTotal DEFAULT 0,
        CreatedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_InvoiceLines_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(256)     NULL,
        ModifiedAt   DATETIME2(3)      NULL,
        ModifiedBy   NVARCHAR(256)     NULL,
        IsDeleted    BIT               NOT NULL CONSTRAINT DF_InvoiceLines_IsDeleted DEFAULT 0,
        -- No FK_InvoiceLines_Invoices cascade: financial detail rows are
        -- removed by explicit application logic, never as a delete side
        -- effect on the parent invoice.
        CONSTRAINT PK_InvoiceLines PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_InvoiceLines_Invoices FOREIGN KEY (InvoiceId) REFERENCES billing.Invoices (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_InvoiceLines_Shipments FOREIGN KEY (ShipmentId) REFERENCES ops.Shipments (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_InvoiceLines_Quantity CHECK (Quantity > 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceLines_InvoiceId' AND object_id = OBJECT_ID('billing.InvoiceLines'))
    CREATE NONCLUSTERED INDEX IX_InvoiceLines_InvoiceId ON billing.InvoiceLines (InvoiceId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_InvoiceLines_ShipmentId' AND object_id = OBJECT_ID('billing.InvoiceLines'))
    CREATE NONCLUSTERED INDEX IX_InvoiceLines_ShipmentId ON billing.InvoiceLines (ShipmentId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.Payments') AND type = 'U')
BEGIN
    CREATE TABLE billing.Payments
    (
        Id            INT IDENTITY(1,1) NOT NULL,
        InvoiceId     INT               NOT NULL,
        PaymentDate   DATE              NOT NULL,
        Amount        DECIMAL(18,2)     NOT NULL,
        Method        NVARCHAR(50)      NOT NULL,
        ReferenceNo   NVARCHAR(100)     NULL,
        CreatedAt     DATETIME2(3)      NOT NULL CONSTRAINT DF_Payments_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy     NVARCHAR(256)     NULL,
        ModifiedAt    DATETIME2(3)      NULL,
        ModifiedBy    NVARCHAR(256)     NULL,
        IsDeleted     BIT               NOT NULL CONSTRAINT DF_Payments_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Payments PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Payments_Invoices FOREIGN KEY (InvoiceId) REFERENCES billing.Invoices (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_Payments_Amount CHECK (Amount > 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payments_InvoiceId' AND object_id = OBJECT_ID('billing.Payments'))
    CREATE NONCLUSTERED INDEX IX_Payments_InvoiceId ON billing.Payments (InvoiceId);
GO
