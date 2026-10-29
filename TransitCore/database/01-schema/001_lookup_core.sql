/*
  Purpose:      Core lookup tables needed by the Identity domain (Regions,
                Branches, Designations, WorkingDesignations). Additional
                generic lookups (Countries, Cities, StatusCodes,
                UnitsOfMeasure) are added later, in the Fleet/Ops slice.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: None (run first)
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'lookup')
    EXEC('CREATE SCHEMA lookup');
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('lookup.Regions') AND type = 'U')
BEGIN
    CREATE TABLE lookup.Regions
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Name        NVARCHAR(200)     NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_Regions_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_Regions_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Regions PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Regions_Name UNIQUE (Name)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('lookup.Branches') AND type = 'U')
BEGIN
    CREATE TABLE lookup.Branches
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Name        NVARCHAR(200)     NOT NULL,
        RegionId    INT               NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_Branches_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_Branches_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Branches PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Branches_Regions FOREIGN KEY (RegionId) REFERENCES lookup.Regions (Id) ON DELETE NO ACTION,
        CONSTRAINT UQ_Branches_Name UNIQUE (Name)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Branches_RegionId' AND object_id = OBJECT_ID('lookup.Branches'))
    CREATE NONCLUSTERED INDEX IX_Branches_RegionId ON lookup.Branches (RegionId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('lookup.Designations') AND type = 'U')
BEGIN
    CREATE TABLE lookup.Designations
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Code        NVARCHAR(50)      NOT NULL,
        Name        NVARCHAR(200)     NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_Designations_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_Designations_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Designations PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Designations_Code UNIQUE (Code)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('lookup.WorkingDesignations') AND type = 'U')
BEGIN
    CREATE TABLE lookup.WorkingDesignations
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        Name        NVARCHAR(200)     NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_WorkingDesignations_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_WorkingDesignations_IsDeleted DEFAULT 0,
        CONSTRAINT PK_WorkingDesignations PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_WorkingDesignations_Name UNIQUE (Name)
    );
END
GO
