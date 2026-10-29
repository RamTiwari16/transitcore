/*
  Purpose:      Operations domain — starts with VehicleOrderMapping, the one
                real operational feature that existed in the reference app
                (Excel bulk-upload linking a vehicle number to an order
                number). Trips/Routes/Shipments land in a later slice.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: None
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ops')
    EXEC('CREATE SCHEMA ops');
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('ops.VehicleOrderMapping') AND type = 'U')
BEGIN
    CREATE TABLE ops.VehicleOrderMapping
    (
        Id              INT IDENTITY(1,1) NOT NULL,
        VehicleNo       NVARCHAR(50)      NOT NULL,
        OrderNo         NVARCHAR(50)      NOT NULL,
        UploadDate      DATE              NOT NULL,
        CreatedByEmail  NVARCHAR(256)     NOT NULL,
        CreatedAt       DATETIME2(3)      NOT NULL CONSTRAINT DF_VehicleOrderMapping_CreatedAt DEFAULT SYSUTCDATETIME(),
        CreatedBy       NVARCHAR(256)     NULL,
        ModifiedAt      DATETIME2(3)      NULL,
        ModifiedBy      NVARCHAR(256)     NULL,
        IsDeleted       BIT               NOT NULL CONSTRAINT DF_VehicleOrderMapping_IsDeleted DEFAULT 0,
        CONSTRAINT PK_VehicleOrderMapping PRIMARY KEY CLUSTERED (Id)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VehicleOrderMapping_UploadDate' AND object_id = OBJECT_ID('ops.VehicleOrderMapping'))
    CREATE NONCLUSTERED INDEX IX_VehicleOrderMapping_UploadDate ON ops.VehicleOrderMapping (UploadDate);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VehicleOrderMapping_VehicleNo' AND object_id = OBJECT_ID('ops.VehicleOrderMapping'))
    CREATE NONCLUSTERED INDEX IX_VehicleOrderMapping_VehicleNo ON ops.VehicleOrderMapping (VehicleNo);
GO

IF NOT EXISTS (SELECT 1 FROM sys.types WHERE name = 'VehicleOrderMappingType' AND schema_id = SCHEMA_ID('ops'))
BEGIN
    CREATE TYPE ops.VehicleOrderMappingType AS TABLE
    (
        VehicleNo      NVARCHAR(50)  NOT NULL,
        OrderNo        NVARCHAR(50)  NOT NULL,
        UploadDate     DATE          NOT NULL,
        CreatedByEmail NVARCHAR(256) NOT NULL
    );
END
GO
