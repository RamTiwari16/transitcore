/*
  Purpose:      Fleet domain procedures - vehicle CRUD, driver/vehicle-type
                lookups, and the fleet utilisation heavy read path.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 006_fleet_schema.sql, 008_ops_routes_trips_shipments_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

IF OBJECT_ID('fleet.usp_GetVehicleTypes', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetVehicleTypes;
GO

CREATE PROCEDURE fleet.usp_GetVehicleTypes
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Name, Description, CapacityKg
        FROM fleet.VehicleTypes
        WHERE IsDeleted = 0
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_GetVehicles', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetVehicles;
GO

CREATE PROCEDURE fleet.usp_GetVehicles
    @StatusId      INT = NULL,
    @VehicleTypeId INT = NULL,
    @PageNumber    INT = 1,
    @PageSize      INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            v.Id, v.RegistrationNo, v.VehicleTypeId, vt.Name AS VehicleTypeName,
            v.Make, v.Model, v.ManufactureYear, v.CapacityKg,
            v.StatusId, sc.Name AS StatusName,
            COUNT(*) OVER() AS TotalCount
        FROM fleet.Vehicles v
        INNER JOIN fleet.VehicleTypes vt ON vt.Id = v.VehicleTypeId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = v.StatusId
        WHERE v.IsDeleted = 0
          AND (@StatusId IS NULL OR v.StatusId = @StatusId)
          AND (@VehicleTypeId IS NULL OR v.VehicleTypeId = @VehicleTypeId)
        ORDER BY v.RegistrationNo
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_GetVehicleById', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetVehicleById;
GO

CREATE PROCEDURE fleet.usp_GetVehicleById
    @VehicleId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            v.Id, v.RegistrationNo, v.VehicleTypeId, vt.Name AS VehicleTypeName,
            v.Make, v.Model, v.ManufactureYear, v.CapacityKg,
            v.StatusId, sc.Name AS StatusName, v.CreatedAt, v.CreatedBy
        FROM fleet.Vehicles v
        INNER JOIN fleet.VehicleTypes vt ON vt.Id = v.VehicleTypeId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = v.StatusId
        WHERE v.Id = @VehicleId AND v.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_InsertVehicle', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_InsertVehicle;
GO

CREATE PROCEDURE fleet.usp_InsertVehicle
    @RegistrationNo   NVARCHAR(30),
    @VehicleTypeId    INT,
    @Make             NVARCHAR(100) = NULL,
    @Model            NVARCHAR(100) = NULL,
    @ManufactureYear  INT = NULL,
    @CapacityKg       DECIMAL(18,2),
    @StatusId         INT,
    @CreatedBy        NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO fleet.Vehicles
            (RegistrationNo, VehicleTypeId, Make, Model, ManufactureYear, CapacityKg, StatusId, CreatedBy)
        VALUES
            (@RegistrationNo, @VehicleTypeId, @Make, @Model, @ManufactureYear, @CapacityKg, @StatusId, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS VehicleId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_UpdateVehicle', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_UpdateVehicle;
GO

CREATE PROCEDURE fleet.usp_UpdateVehicle
    @VehicleId        INT,
    @VehicleTypeId    INT,
    @Make             NVARCHAR(100) = NULL,
    @Model            NVARCHAR(100) = NULL,
    @ManufactureYear  INT = NULL,
    @CapacityKg       DECIMAL(18,2),
    @StatusId         INT,
    @ModifiedBy       NVARCHAR(256),
    @IsUpdated        BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE fleet.Vehicles
        SET VehicleTypeId   = @VehicleTypeId,
            Make             = @Make,
            Model            = @Model,
            ManufactureYear  = @ManufactureYear,
            CapacityKg       = @CapacityKg,
            StatusId         = @StatusId,
            ModifiedBy       = @ModifiedBy,
            ModifiedAt       = SYSUTCDATETIME()
        WHERE Id = @VehicleId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_GetDrivers', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetDrivers;
GO

CREATE PROCEDURE fleet.usp_GetDrivers
    @StatusId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT d.Id, d.FullName, d.PhoneNo, d.Email, d.HireDate, d.StatusId, sc.Name AS StatusName
        FROM fleet.Drivers d
        INNER JOIN lookup.StatusCodes sc ON sc.Id = d.StatusId
        WHERE d.IsDeleted = 0
          AND (@StatusId IS NULL OR d.StatusId = @StatusId)
        ORDER BY d.FullName;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_InsertDriver', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_InsertDriver;
GO

CREATE PROCEDURE fleet.usp_InsertDriver
    @FullName     NVARCHAR(200),
    @PhoneNo      NVARCHAR(30) = NULL,
    @Email        NVARCHAR(256) = NULL,
    @DateOfBirth  DATE = NULL,
    @HireDate     DATE = NULL,
    @StatusId     INT,
    @CreatedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO fleet.Drivers
            (FullName, PhoneNo, Email, DateOfBirth, HireDate, StatusId, CreatedBy)
        VALUES
            (@FullName, @PhoneNo, @Email, @DateOfBirth, @HireDate, @StatusId, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS DriverId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

/*
  Heavy read path: fleet utilisation over a date range. Utilisation% is
  scheduled trip hours within the window divided by total available hours
  in the window (24h * days in range) per vehicle - a simple, explainable
  definition the UI can show a tooltip for; refine later if a different
  utilisation formula is wanted.
*/
IF OBJECT_ID('fleet.usp_GetFleetUtilisation', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetFleetUtilisation;
GO

CREATE PROCEDURE fleet.usp_GetFleetUtilisation
    @FromDate DATE,
    @ToDate   DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @AvailableHours DECIMAL(18,2) = DATEDIFF(HOUR, @FromDate, DATEADD(DAY, 1, @ToDate));

        SELECT
            v.Id AS VehicleId,
            v.RegistrationNo,
            vt.Name AS VehicleTypeName,
            COUNT(t.Id) AS TotalTrips,
            ISNULL(SUM(DATEDIFF(MINUTE, t.ScheduledDeparture, t.ScheduledArrival)), 0) / 60.0 AS ScheduledHours,
            CASE WHEN @AvailableHours > 0
                 THEN ROUND((ISNULL(SUM(DATEDIFF(MINUTE, t.ScheduledDeparture, t.ScheduledArrival)), 0) / 60.0) / @AvailableHours * 100, 2)
                 ELSE 0
            END AS UtilisationPercent
        FROM fleet.Vehicles v
        INNER JOIN fleet.VehicleTypes vt ON vt.Id = v.VehicleTypeId
        LEFT JOIN ops.Trips t
            ON t.VehicleId = v.Id
           AND t.IsDeleted = 0
           AND t.ScheduledDeparture >= @FromDate
           AND t.ScheduledDeparture < DATEADD(DAY, 1, @ToDate)
        WHERE v.IsDeleted = 0
        GROUP BY v.Id, v.RegistrationNo, vt.Name
        ORDER BY UtilisationPercent DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
