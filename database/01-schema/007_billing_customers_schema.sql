/*
  Purpose:      Customer master data. Lives in the billing schema since
                Invoices/RateCards/Shipments all key off Customers directly,
                and the brief's five schemas don't include a separate
                "customers" schema.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 005_lookup_extended.sql (Cities)
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'billing')
    EXEC('CREATE SCHEMA billing');
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.Customers') AND type = 'U')
BEGIN
    CREATE TABLE billing.Customers
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Code        NVARCHAR(50)      NOT NULL,
        Name        NVARCHAR(200)     NOT NULL,
        IsActive    BIT               NOT NULL CONSTRAINT DF_Customers_IsActive DEFAULT 1,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_Customers_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_Customers_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Customers PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Customers_Code UNIQUE (Code)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.CustomerContacts') AND type = 'U')
BEGIN
    CREATE TABLE billing.CustomerContacts
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        CustomerId   INT               NOT NULL,
        ContactName  NVARCHAR(200)     NOT NULL,
        Email        NVARCHAR(256)     NULL,
        PhoneNo      NVARCHAR(30)      NULL,
        IsPrimary    BIT               NOT NULL CONSTRAINT DF_CustomerContacts_IsPrimary DEFAULT 0,
        CreatedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_CustomerContacts_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(256)     NULL,
        ModifiedAt   DATETIME2(3)      NULL,
        ModifiedBy   NVARCHAR(256)     NULL,
        IsDeleted    BIT               NOT NULL CONSTRAINT DF_CustomerContacts_IsDeleted DEFAULT 0,
        CONSTRAINT PK_CustomerContacts PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_CustomerContacts_Customers FOREIGN KEY (CustomerId) REFERENCES billing.Customers (Id) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CustomerContacts_CustomerId' AND object_id = OBJECT_ID('billing.CustomerContacts'))
    CREATE NONCLUSTERED INDEX IX_CustomerContacts_CustomerId ON billing.CustomerContacts (CustomerId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('billing.CustomerAddresses') AND type = 'U')
BEGIN
    CREATE TABLE billing.CustomerAddresses
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        CustomerId  INT               NOT NULL,
        Line1       NVARCHAR(300)     NOT NULL,
        Line2       NVARCHAR(300)     NULL,
        CityId      INT               NOT NULL,
        PostalCode  NVARCHAR(20)      NULL,
        IsPrimary   BIT               NOT NULL CONSTRAINT DF_CustomerAddresses_IsPrimary DEFAULT 0,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_CustomerAddresses_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_CustomerAddresses_IsDeleted DEFAULT 0,
        CONSTRAINT PK_CustomerAddresses PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_CustomerAddresses_Customers FOREIGN KEY (CustomerId) REFERENCES billing.Customers (Id) ON DELETE CASCADE,
        CONSTRAINT FK_CustomerAddresses_Cities FOREIGN KEY (CityId) REFERENCES lookup.Cities (Id) ON DELETE NO ACTION
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CustomerAddresses_CustomerId' AND object_id = OBJECT_ID('billing.CustomerAddresses'))
    CREATE NONCLUSTERED INDEX IX_CustomerAddresses_CustomerId ON billing.CustomerAddresses (CustomerId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CustomerAddresses_CityId' AND object_id = OBJECT_ID('billing.CustomerAddresses'))
    CREATE NONCLUSTERED INDEX IX_CustomerAddresses_CityId ON billing.CustomerAddresses (CityId);
GO
