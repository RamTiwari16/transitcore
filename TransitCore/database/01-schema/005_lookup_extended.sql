/*
  Purpose:      Generic lookups needed by the Fleet/Ops/Billing domain:
                Countries, Cities, StatusCodes, UnitsOfMeasure.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: None
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('lookup.Countries') AND type = 'U')
BEGIN
    CREATE TABLE lookup.Countries
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Code        NVARCHAR(3)       NOT NULL,
        Name        NVARCHAR(200)     NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_Countries_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_Countries_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Countries PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Countries_Code UNIQUE (Code)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('lookup.Cities') AND type = 'U')
BEGIN
    CREATE TABLE lookup.Cities
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Name        NVARCHAR(200)     NOT NULL,
        CountryId   INT               NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_Cities_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_Cities_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Cities PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Cities_Countries FOREIGN KEY (CountryId) REFERENCES lookup.Countries (Id) ON DELETE NO ACTION
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Cities_CountryId' AND object_id = OBJECT_ID('lookup.Cities'))
    CREATE NONCLUSTERED INDEX IX_Cities_CountryId ON lookup.Cities (CountryId);
GO

-- Category groups status codes by the domain they apply to (e.g. 'Vehicle',
-- 'Trip', 'Shipment', 'Invoice'), so one table serves every domain's status
-- needs instead of a separate enum-like table per domain.
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('lookup.StatusCodes') AND type = 'U')
BEGIN
    CREATE TABLE lookup.StatusCodes
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Category    NVARCHAR(50)      NOT NULL,
        Code        NVARCHAR(50)      NOT NULL,
        Name        NVARCHAR(150)     NOT NULL,
        SortOrder   INT               NOT NULL CONSTRAINT DF_StatusCodes_SortOrder DEFAULT 0,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_StatusCodes_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_StatusCodes_IsDeleted DEFAULT 0,
        CONSTRAINT PK_StatusCodes PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_StatusCodes_Category_Code UNIQUE (Category, Code)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('lookup.UnitsOfMeasure') AND type = 'U')
BEGIN
    CREATE TABLE lookup.UnitsOfMeasure
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Code        NVARCHAR(20)      NOT NULL,
        Name        NVARCHAR(100)     NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_UnitsOfMeasure_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_UnitsOfMeasure_IsDeleted DEFAULT 0,
        CONSTRAINT PK_UnitsOfMeasure PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_UnitsOfMeasure_Code UNIQUE (Code)
    );
END
GO
