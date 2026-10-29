/*
  Purpose:      Operations domain - Routes, Trips, Shipments (the actual
                transit/logistics work). Builds on fleet (vehicles/drivers),
                billing (customers), and lookup (cities/status codes).
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 005_lookup_extended.sql, 006_fleet_schema.sql,
                007_billing_customers_schema.sql
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.Routes') AND type = 'U')
BEGIN
    CREATE TABLE ops.Routes
    (
        Id                 INT IDENTITY(1,1) NOT NULL,
        Name               NVARCHAR(200)     NOT NULL,
        OriginCityId       INT               NOT NULL,
        DestinationCityId  INT               NOT NULL,
        DistanceKm         DECIMAL(18,2)     NULL,
        CreatedAt          DATETIME2(3)      NOT NULL CONSTRAINT DF_Routes_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy          NVARCHAR(256)     NULL,
        ModifiedAt         DATETIME2(3)      NULL,
        ModifiedBy         NVARCHAR(256)     NULL,
        IsDeleted          BIT               NOT NULL CONSTRAINT DF_Routes_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Routes PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Routes_OriginCity FOREIGN KEY (OriginCityId) REFERENCES lookup.Cities (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Routes_DestinationCity FOREIGN KEY (DestinationCityId) REFERENCES lookup.Cities (Id) ON DELETE NO ACTION
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Routes_OriginCityId' AND object_id = OBJECT_ID('ops.Routes'))
    CREATE NONCLUSTERED INDEX IX_Routes_OriginCityId ON ops.Routes (OriginCityId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Routes_DestinationCityId' AND object_id = OBJECT_ID('ops.Routes'))
    CREATE NONCLUSTERED INDEX IX_Routes_DestinationCityId ON ops.Routes (DestinationCityId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.RouteStops') AND type = 'U')
BEGIN
    CREATE TABLE ops.RouteStops
    (
        Id               INT IDENTITY(1,1) NOT NULL,
        RouteId          INT               NOT NULL,
        CityId           INT               NOT NULL,
        StopOrder        INT               NOT NULL,
        PlannedArrival   DATETIME2(3)      NULL,
        CreatedAt        DATETIME2(3)      NOT NULL CONSTRAINT DF_RouteStops_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy        NVARCHAR(256)     NULL,
        ModifiedAt       DATETIME2(3)      NULL,
        ModifiedBy       NVARCHAR(256)     NULL,
        IsDeleted        BIT               NOT NULL CONSTRAINT DF_RouteStops_IsDeleted DEFAULT 0,
        CONSTRAINT PK_RouteStops PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_RouteStops_Routes FOREIGN KEY (RouteId) REFERENCES ops.Routes (Id) ON DELETE CASCADE,
        CONSTRAINT FK_RouteStops_Cities FOREIGN KEY (CityId) REFERENCES lookup.Cities (Id) ON DELETE NO ACTION,
        CONSTRAINT UQ_RouteStops_Route_StopOrder UNIQUE (RouteId, StopOrder)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RouteStops_RouteId' AND object_id = OBJECT_ID('ops.RouteStops'))
    CREATE NONCLUSTERED INDEX IX_RouteStops_RouteId ON ops.RouteStops (RouteId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_RouteStops_CityId' AND object_id = OBJECT_ID('ops.RouteStops'))
    CREATE NONCLUSTERED INDEX IX_RouteStops_CityId ON ops.RouteStops (CityId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.Trips') AND type = 'U')
BEGIN
    CREATE TABLE ops.Trips
    (
        Id                  INT IDENTITY(1,1) NOT NULL,
        RouteId             INT               NOT NULL,
        VehicleId           INT               NOT NULL,
        DriverId            INT               NOT NULL,
        ScheduledDeparture  DATETIME2(3)      NOT NULL,
        ScheduledArrival    DATETIME2(3)      NOT NULL,
        ActualDeparture     DATETIME2(3)      NULL,
        ActualArrival       DATETIME2(3)      NULL,
        StatusId            INT               NOT NULL,
        CreatedAt           DATETIME2(3)      NOT NULL CONSTRAINT DF_Trips_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy           NVARCHAR(256)     NULL,
        ModifiedAt          DATETIME2(3)      NULL,
        ModifiedBy          NVARCHAR(256)     NULL,
        IsDeleted           BIT               NOT NULL CONSTRAINT DF_Trips_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Trips PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Trips_Routes FOREIGN KEY (RouteId) REFERENCES ops.Routes (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Trips_Vehicles FOREIGN KEY (VehicleId) REFERENCES fleet.Vehicles (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Trips_Drivers FOREIGN KEY (DriverId) REFERENCES fleet.Drivers (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Trips_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_Trips_ScheduledWindow CHECK (ScheduledArrival >= ScheduledDeparture)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Trips_RouteId' AND object_id = OBJECT_ID('ops.Trips'))
    CREATE NONCLUSTERED INDEX IX_Trips_RouteId ON ops.Trips (RouteId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Trips_VehicleId' AND object_id = OBJECT_ID('ops.Trips'))
    CREATE NONCLUSTERED INDEX IX_Trips_VehicleId ON ops.Trips (VehicleId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Trips_DriverId' AND object_id = OBJECT_ID('ops.Trips'))
    CREATE NONCLUSTERED INDEX IX_Trips_DriverId ON ops.Trips (DriverId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Trips_StatusId' AND object_id = OBJECT_ID('ops.Trips'))
    CREATE NONCLUSTERED INDEX IX_Trips_StatusId ON ops.Trips (StatusId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Trips_ScheduledDeparture' AND object_id = OBJECT_ID('ops.Trips'))
    CREATE NONCLUSTERED INDEX IX_Trips_ScheduledDeparture ON ops.Trips (ScheduledDeparture);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.TripStatusHistory') AND type = 'U')
BEGIN
    CREATE TABLE ops.TripStatusHistory
    (
        Id         INT IDENTITY(1,1) NOT NULL,
        TripId     INT               NOT NULL,
        StatusId   INT               NOT NULL,
        ChangedAt  DATETIME2(3)      NOT NULL CONSTRAINT DF_TripStatusHistory_ChangedAt DEFAULT SYSUTCDATETIME(),
        Notes      NVARCHAR(500)     NULL,
        CreatedBy  NVARCHAR(256)     NULL,
        CONSTRAINT PK_TripStatusHistory PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_TripStatusHistory_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE CASCADE,
        CONSTRAINT FK_TripStatusHistory_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TripStatusHistory_TripId' AND object_id = OBJECT_ID('ops.TripStatusHistory'))
    CREATE NONCLUSTERED INDEX IX_TripStatusHistory_TripId ON ops.TripStatusHistory (TripId);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.Shipments') AND type = 'U')
BEGIN
    CREATE TABLE ops.Shipments
    (
        Id                  INT IDENTITY(1,1) NOT NULL,
        TripId              INT               NULL,
        CustomerId          INT               NOT NULL,
        OriginCityId        INT               NOT NULL,
        DestinationCityId   INT               NOT NULL,
        StatusId            INT               NOT NULL,
        ShipmentDate        DATE              NOT NULL,
        CreatedAt           DATETIME2(3)      NOT NULL CONSTRAINT DF_Shipments_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy           NVARCHAR(256)     NULL,
        ModifiedAt          DATETIME2(3)      NULL,
        ModifiedBy          NVARCHAR(256)     NULL,
        IsDeleted           BIT               NOT NULL CONSTRAINT DF_Shipments_IsDeleted DEFAULT 0,
        CONSTRAINT PK_Shipments PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_Shipments_Trips FOREIGN KEY (TripId) REFERENCES ops.Trips (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Shipments_Customers FOREIGN KEY (CustomerId) REFERENCES billing.Customers (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Shipments_OriginCity FOREIGN KEY (OriginCityId) REFERENCES lookup.Cities (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Shipments_DestinationCity FOREIGN KEY (DestinationCityId) REFERENCES lookup.Cities (Id) ON DELETE NO ACTION,
        CONSTRAINT FK_Shipments_StatusCodes FOREIGN KEY (StatusId) REFERENCES lookup.StatusCodes (Id) ON DELETE NO ACTION
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Shipments_TripId' AND object_id = OBJECT_ID('ops.Shipments'))
    CREATE NONCLUSTERED INDEX IX_Shipments_TripId ON ops.Shipments (TripId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Shipments_CustomerId' AND object_id = OBJECT_ID('ops.Shipments'))
    CREATE NONCLUSTERED INDEX IX_Shipments_CustomerId ON ops.Shipments (CustomerId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Shipments_StatusId' AND object_id = OBJECT_ID('ops.Shipments'))
    CREATE NONCLUSTERED INDEX IX_Shipments_StatusId ON ops.Shipments (StatusId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Shipments_ShipmentDate' AND object_id = OBJECT_ID('ops.Shipments'))
    CREATE NONCLUSTERED INDEX IX_Shipments_ShipmentDate ON ops.Shipments (ShipmentDate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.ShipmentItems') AND type = 'U')
BEGIN
    CREATE TABLE ops.ShipmentItems
    (
        Id               INT IDENTITY(1,1) NOT NULL,
        ShipmentId       INT               NOT NULL,
        Description      NVARCHAR(300)     NOT NULL,
        Quantity         DECIMAL(18,2)     NOT NULL,
        UnitOfMeasureId  INT               NOT NULL,
        WeightKg         DECIMAL(18,2)     NULL,
        CreatedAt        DATETIME2(3)      NOT NULL CONSTRAINT DF_ShipmentItems_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy        NVARCHAR(256)     NULL,
        ModifiedAt       DATETIME2(3)      NULL,
        ModifiedBy       NVARCHAR(256)     NULL,
        IsDeleted        BIT               NOT NULL CONSTRAINT DF_ShipmentItems_IsDeleted DEFAULT 0,
        CONSTRAINT PK_ShipmentItems PRIMARY KEY CLUSTERED (Id),
        CONSTRAINT FK_ShipmentItems_Shipments FOREIGN KEY (ShipmentId) REFERENCES ops.Shipments (Id) ON DELETE CASCADE,
        CONSTRAINT FK_ShipmentItems_UnitsOfMeasure FOREIGN KEY (UnitOfMeasureId) REFERENCES lookup.UnitsOfMeasure (Id) ON DELETE NO ACTION,
        CONSTRAINT CK_ShipmentItems_Quantity CHECK (Quantity > 0)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ShipmentItems_ShipmentId' AND object_id = OBJECT_ID('ops.ShipmentItems'))
    CREATE NONCLUSTERED INDEX IX_ShipmentItems_ShipmentId ON ops.ShipmentItems (ShipmentId);
GO
