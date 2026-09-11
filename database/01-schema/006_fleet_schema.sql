/*
  Purpose:      Fleet domain - vehicle master data, documents, maintenance,
                fuel logs, and driver resources (drivers/licenses/vehicle
                assignments live here too, since they're fleet resources).
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 005_lookup_extended.sql (StatusCodes)
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'fleet')
    EXEC('CREATE SCHEMA fleet');
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('fleet.VehicleTypes') AND type = 'U')
BEGIN
    CREATE TABLE fleet.VehicleTypes
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        Name         NVARCHAR(100)     NOT NULL,
        Description  NVARCHAR(300)     NULL,
        CapacityKg   DECIMAL(18,2)     NOT NULL CONSTRAINT DF_VehicleTypes_CapacityKg DEFAULT 0,
        CreatedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_VehicleTypes_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(256)     NULL,
        ModifiedAt   DATETIME2(3)      NULL,
        ModifiedBy   NVARCHAR(256)     NULL,
        IsDeleted    BIT               NOT NULL CONSTRAINT DF_VehicleTypes_IsDeleted DEFAULT 0,
        CONSTRAINT PK_VehicleTypes PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_VehicleTypes_Name UNIQUE (Name)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('fleet.Vehicles') AND type = 'U')
BEGIN
    CREATE TABLE fleet.Vehicles
    (
        Id              INT IDENTITY(1,1) NOT NULL,
        RegistrationNo  NVARCHAR(30)      NOT NULL,
        VehicleTypeId   INT               NOT NULL,
        Make            NVARCHAR(100)     NULL,
        Model           NVARCHAR(100)     NULL,
        ManufactureYear INT               NULL,
        CapacityKg      DECIMAL(18,2)     NOT NULL CONSTRAINT DF_Vehicles_CapacityKg DEFAULT 0,
        StatusId        INT               NOT NULL,
        CreatedAt       DATETIME2(3)      NOT NULL CONSTRAINT DF_Vehicles_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy       NVARCHAR(256)     NULL,
        ModifiedAt      DATETIME2(3)      NULL,
        ModifiedBy      NVARCHAR(256)     NULL,
        IsDeleted       BIT               NOT NULL CONSTRAINT DF_Vehicles_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Vehicles PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT UQ_Vehicles_RegistrationNo UNIQUE (RegistrationNo),
        CONSTRAINT FK_Vehicles_VehicleTypes FOREIGN KEY (VehicleTypeId) REFERENCES fleet.VehicleTypes (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Vehicles_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_Vehicles_ManufactureYear CHECK (ManufactureYear IS NULL OR ManufactureYear BETWEEN 1980 AND 2100)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Vehicles_VehicleTypeId' AND object_id = OBJECT_ID('fleet.Vehicles'))
    CREATE NONCLUSTERED INDEX IX_Vehicles_VehicleTypeId ON fleet.Vehicles (VehicleTypeId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Vehicles_StatusId' AND object_id = OBJECT_ID('fleet.Vehicles'))
    CREATE NONCLUSTERED INDEX IX_Vehicles_StatusId ON fleet.Vehicles (StatusId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('fleet.VehicleDocuments') AND type = 'U')
BEGIN
    CREATE TABLE fleet.VehicleDocuments
    (
        Id             INT IDENTITY(1,1) NOT NULL,
        VehicleId      INT               NOT NULL,
        DocumentType   NVARCHAR(100)     NOT NULL,
        DocumentNo     NVARCHAR(100)     NULL,
        IssuedDate     DATE              NULL,
        ExpiryDate     DATE              NULL,
        CreatedAt      DATETIME2(3)      NOT NULL CONSTRAINT DF_VehicleDocuments_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy      NVARCHAR(256)     NULL,
        ModifiedAt     DATETIME2(3)      NULL,
        ModifiedBy     NVARCHAR(256)     NULL,
        IsDeleted      BIT               NOT NULL CONSTRAINT DF_VehicleDocuments_IsDeleted DEFAULT 0,
        CONSTRAINT PK_VehicleDocuments PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_VehicleDocuments_Vehicles FOREIGN KEY (VehicleId) REFERENCES fleet.Vehicles (Id) ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VehicleDocuments_VehicleId' AND object_id = OBJECT_ID('fleet.VehicleDocuments'))
    CREATE NONCLUSTERED INDEX IX_VehicleDocuments_VehicleId ON fleet.VehicleDocuments (VehicleId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VehicleDocuments_ExpiryDate' AND object_id = OBJECT_ID('fleet.VehicleDocuments'))
    CREATE NONCLUSTERED INDEX IX_VehicleDocuments_ExpiryDate ON fleet.VehicleDocuments (ExpiryDate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('fleet.MaintenanceRecords') AND type = 'U')
BEGIN
    CREATE TABLE fleet.MaintenanceRecords
    (
        Id           INT IDENTITY(1,1) NOT NULL,
        VehicleId    INT               NOT NULL,
        ServiceDate  DATE              NOT NULL,
        Description  NVARCHAR(500)     NULL,
        Cost         DECIMAL(18,2)     NOT NULL CONSTRAINT DF_MaintenanceRecords_Cost DEFAULT 0,
        OdometerKm   INT               NULL,
        PerformedBy  NVARCHAR(200)     NULL,
        CreatedAt    DATETIME2(3)      NOT NULL CONSTRAINT DF_MaintenanceRecords_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy    NVARCHAR(256)     NULL,
        ModifiedAt   DATETIME2(3)      NULL,
        ModifiedBy   NVARCHAR(256)     NULL,
        IsDeleted    BIT               NOT NULL CONSTRAINT DF_MaintenanceRecords_IsDeleted DEFAULT 0,
        CONSTRAINT PK_MaintenanceRecords PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_MaintenanceRecords_Vehicles FOREIGN KEY (VehicleId) REFERENCES fleet.Vehicles (Id) ON DELETE CASCADE,
        CONSTRAINT CK_MaintenanceRecords_Cost CHECK (Cost >= 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MaintenanceRecords_VehicleId' AND object_id = OBJECT_ID('fleet.MaintenanceRecords'))
    CREATE NONCLUSTERED INDEX IX_MaintenanceRecords_VehicleId ON fleet.MaintenanceRecords (VehicleId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MaintenanceRecords_ServiceDate' AND object_id = OBJECT_ID('fleet.MaintenanceRecords'))
    CREATE NONCLUSTERED INDEX IX_MaintenanceRecords_ServiceDate ON fleet.MaintenanceRecords (ServiceDate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('fleet.FuelLogs') AND type = 'U')
BEGIN
    CREATE TABLE fleet.FuelLogs
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        VehicleId   INT               NOT NULL,
        FuelDate    DATE              NOT NULL,
        Liters      DECIMAL(18,2)     NOT NULL,
        Cost        DECIMAL(18,2)     NOT NULL,
        OdometerKm  INT               NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_FuelLogs_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_FuelLogs_IsDeleted DEFAULT 0,
        CONSTRAINT PK_FuelLogs PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_FuelLogs_Vehicles FOREIGN KEY (VehicleId) REFERENCES fleet.Vehicles (Id) ON DELETE CASCADE,
        CONSTRAINT CK_FuelLogs_Liters CHECK (Liters >= 0),
        CONSTRAINT CK_FuelLogs_Cost CHECK (Cost >= 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FuelLogs_VehicleId' AND object_id = OBJECT_ID('fleet.FuelLogs'))
    CREATE NONCLUSTERED INDEX IX_FuelLogs_VehicleId ON fleet.FuelLogs (VehicleId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_FuelLogs_FuelDate' AND object_id = OBJECT_ID('fleet.FuelLogs'))
    CREATE NONCLUSTERED INDEX IX_FuelLogs_FuelDate ON fleet.FuelLogs (FuelDate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('fleet.Drivers') AND type = 'U')
BEGIN
    CREATE TABLE fleet.Drivers
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        FullName    NVARCHAR(200)     NOT NULL,
        PhoneNo     NVARCHAR(30)      NULL,
        Email       NVARCHAR(256)     NULL,
        DateOfBirth DATE              NULL,
        HireDate    DATE              NULL,
        StatusId    INT               NOT NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_Drivers_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_Drivers_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Drivers PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Drivers_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Drivers_StatusId' AND object_id = OBJECT_ID('fleet.Drivers'))
    CREATE NONCLUSTERED INDEX IX_Drivers_StatusId ON fleet.Drivers (StatusId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('fleet.DriverLicenses') AND type = 'U')
BEGIN
    CREATE TABLE fleet.DriverLicenses
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        DriverId    INT               NOT NULL,
        LicenseNo   NVARCHAR(100)     NOT NULL,
        LicenseType NVARCHAR(50)      NULL,
        IssuedDate  DATE              NULL,
        ExpiryDate  DATE              NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_DriverLicenses_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_DriverLicenses_IsDeleted DEFAULT 0,
        CONSTRAINT PK_DriverLicenses PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_DriverLicenses_Drivers FOREIGN KEY (DriverId) REFERENCES fleet.Drivers (Id) ON DELETE CASCADE,
        CONSTRAINT UQ_DriverLicenses_LicenseNo UNIQUE (LicenseNo)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DriverLicenses_DriverId' AND object_id = OBJECT_ID('fleet.DriverLicenses'))
    CREATE NONCLUSTERED INDEX IX_DriverLicenses_DriverId ON fleet.DriverLicenses (DriverId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('fleet.DriverAssignments') AND type = 'U')
BEGIN
    CREATE TABLE fleet.DriverAssignments
    (
        Id          INT IDENTITY(1,1) NOT NULL,
        DriverId    INT               NOT NULL,
        VehicleId   INT               NOT NULL,
        StartDate   DATE              NOT NULL,
        EndDate     DATE              NULL,
        CreatedAt   DATETIME2(3)      NOT NULL CONSTRAINT DF_DriverAssignments_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy   NVARCHAR(256)     NULL,
        ModifiedAt  DATETIME2(3)      NULL,
        ModifiedBy  NVARCHAR(256)     NULL,
        IsDeleted   BIT               NOT NULL CONSTRAINT DF_DriverAssignments_IsDeleted DEFAULT 0,
        CONSTRAINT PK_DriverAssignments PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_DriverAssignments_Drivers FOREIGN KEY (DriverId) REFERENCES fleet.Drivers (Id) ON DELETE CASCADE,
        CONSTRAINT FK_DriverAssignments_Vehicles FOREIGN KEY (VehicleId) REFERENCES fleet.Vehicles (Id) ON DELETE CASCADE,
        CONSTRAINT CK_DriverAssignments_Dates CHECK (EndDate IS NULL OR EndDate >= StartDate)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DriverAssignments_DriverId' AND object_id = OBJECT_ID('fleet.DriverAssignments'))
    CREATE NONCLUSTERED INDEX IX_DriverAssignments_DriverId ON fleet.DriverAssignments (DriverId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DriverAssignments_VehicleId' AND object_id = OBJECT_ID('fleet.DriverAssignments'))
    CREATE NONCLUSTERED INDEX IX_DriverAssignments_VehicleId ON fleet.DriverAssignments (VehicleId);
GO
