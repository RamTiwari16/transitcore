/*
  Purpose:      Phase 2 (Fleet depth) - CRUD + expiry-alert procs for
                DriverLicenses (covers both driving licence and medical
                certificate records - LicenseType is free text, e.g.
                "Driving License" / "Medical Certificate", rather than two
                separate tables for what's structurally the same "a document
                with an expiry date" shape), plus a read-only driver
                performance aggregate computed from ops.Trips - there's no
                separate performance table, the metrics are derived.
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 01-schema/006_fleet_schema.sql, 008_ops_routes_trips_shipments_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO

-- ========== fleet.DriverLicenses ==========

IF OBJECT_ID('fleet.usp_GetDriverLicenses', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetDriverLicenses;
GO

CREATE PROCEDURE fleet.usp_GetDriverLicenses
    @DriverId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, DriverId, LicenseNo, LicenseType, IssuedDate, ExpiryDate
        FROM fleet.DriverLicenses
        WHERE DriverId = @DriverId AND IsDeleted = 0
        ORDER BY ISNULL(ExpiryDate, '9999-12-31') ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_InsertDriverLicense', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_InsertDriverLicense;
GO

CREATE PROCEDURE fleet.usp_InsertDriverLicense
    @DriverId     INT,
    @LicenseNo    NVARCHAR(100),
    @LicenseType  NVARCHAR(50) = NULL,
    @IssuedDate   DATE = NULL,
    @ExpiryDate   DATE = NULL,
    @CreatedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO fleet.DriverLicenses (DriverId, LicenseNo, LicenseType, IssuedDate, ExpiryDate, CreatedBy)
        VALUES (@DriverId, @LicenseNo, @LicenseType, @IssuedDate, @ExpiryDate, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('fleet.usp_DeleteDriverLicense', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_DeleteDriverLicense;
GO

CREATE PROCEDURE fleet.usp_DeleteDriverLicense
    @LicenseId   INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE fleet.DriverLicenses
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @LicenseId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Feeds the Dashboard alerts panel - licenses (driving or medical) already
-- expired or expiring within @DaysAhead days, across all drivers.
IF OBJECT_ID('fleet.usp_GetExpiringDriverLicenses', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetExpiringDriverLicenses;
GO

CREATE PROCEDURE fleet.usp_GetExpiringDriverLicenses
    @DaysAhead INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            l.Id, l.DriverId, d.FullName AS DriverName, l.LicenseType, l.LicenseNo, l.ExpiryDate
        FROM fleet.DriverLicenses l
        INNER JOIN fleet.Drivers d ON d.Id = l.DriverId
        WHERE l.IsDeleted = 0
          AND l.ExpiryDate IS NOT NULL
          AND l.ExpiryDate <= DATEADD(DAY, @DaysAhead, CAST(SYSUTCDATETIME() AS DATE))
        ORDER BY l.ExpiryDate ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Driver performance (derived from ops.Trips, no new table) ==========

IF OBJECT_ID('fleet.usp_GetDriverPerformance', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetDriverPerformance;
GO

CREATE PROCEDURE fleet.usp_GetDriverPerformance
    @DriverId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Counts/sums only - percentages are computed in the API layer to
        -- keep a zero-completed-trips driver from needing a divide-by-zero
        -- guard here.
        SELECT
            @DriverId AS DriverId,
            COUNT(*) AS TotalTrips,
            -- SUM over zero rows is NULL, not 0 (a driver with no trips yet).
            ISNULL(SUM(CASE WHEN sc.Name = 'Completed' THEN 1 ELSE 0 END), 0) AS CompletedTrips,
            ISNULL(SUM(CASE WHEN sc.Name = 'Completed' AND t.ActualArrival IS NOT NULL
                          AND t.ActualArrival <= t.ScheduledArrival THEN 1 ELSE 0 END), 0) AS OnTimeTrips,
            ISNULL(SUM(CASE WHEN sc.Name = 'Delayed' THEN 1 ELSE 0 END), 0) AS DelayedTrips,
            ISNULL(SUM(CASE WHEN sc.Name = 'Completed' THEN ISNULL(r.DistanceKm, 0) ELSE 0 END), 0) AS TotalDistanceKm
        FROM ops.Trips t
        INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        WHERE t.DriverId = @DriverId AND t.IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
