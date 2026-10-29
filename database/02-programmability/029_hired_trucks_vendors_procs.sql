/*
  Purpose:      Phase 4 (F5) programmability. Vendor CRUD; regenerates every
                proc that INNER JOINs ops.Trips to fleet.Vehicles/
                fleet.Drivers (now LEFT JOIN, since a Hired trip has
                neither) - usp_GetTrips, usp_GetTripById, usp_InsertTrip,
                usp_UpdateTrip, usp_CheckTripConflicts,
                usp_GetTripCapacityCheck, dbo.usp_GlobalSearch's Trip
                branch; regenerates fleet.usp_GetFleetUtilisationTrend to
                exclude Hired-trip hours from fleet utilisation%; adds
                vendor advances/deductions (ops, mirroring TripExpenses/
                TripAdvances) and VendorBills/VendorPayments (billing,
                mirroring Invoices/Payments) plus a vendor outstanding/aging
                report; regenerates usp_GetTripCostSummary to add the
                customer-charges and vendor-freight figures trip profit
                needs.
  Author:       TransitCore rebuild
  Date:         2026-10-05
  Dependencies: 01-schema/018_hired_trucks_vendors_schema.sql
*/
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- ========== billing.Vendors ==========

IF OBJECT_ID('billing.usp_GetVendors', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetVendors;
GO

CREATE PROCEDURE billing.usp_GetVendors
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Code, Name, ContactName, ContactPhone, ContactEmail, Address,
               BankAccountNo, BankIfscCode, PanNo, GstinNo, IsActive
        FROM billing.Vendors
        WHERE IsDeleted = 0
          AND (@ActiveOnly = 0 OR IsActive = 1)
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetVendorById', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetVendorById;
GO

CREATE PROCEDURE billing.usp_GetVendorById
    @VendorId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Code, Name, ContactName, ContactPhone, ContactEmail, Address,
               BankAccountNo, BankIfscCode, PanNo, GstinNo, IsActive
        FROM billing.Vendors
        WHERE Id = @VendorId AND IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_InsertVendor', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertVendor;
GO

CREATE PROCEDURE billing.usp_InsertVendor
    @Code           NVARCHAR(50),
    @Name           NVARCHAR(200),
    @ContactName    NVARCHAR(200) = NULL,
    @ContactPhone   NVARCHAR(30) = NULL,
    @ContactEmail   NVARCHAR(256) = NULL,
    @Address        NVARCHAR(300) = NULL,
    @BankAccountNo  NVARCHAR(50) = NULL,
    @BankIfscCode   NVARCHAR(20) = NULL,
    @PanNo          NVARCHAR(20) = NULL,
    @GstinNo        NVARCHAR(20) = NULL,
    @CreatedBy      NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO billing.Vendors
            (Code, Name, ContactName, ContactPhone, ContactEmail, Address, BankAccountNo, BankIfscCode, PanNo, GstinNo, CreatedBy)
        VALUES
            (@Code, @Name, @ContactName, @ContactPhone, @ContactEmail, @Address, @BankAccountNo, @BankIfscCode, @PanNo, @GstinNo, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS VendorId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_UpdateVendor', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_UpdateVendor;
GO

CREATE PROCEDURE billing.usp_UpdateVendor
    @VendorId       INT,
    @Name           NVARCHAR(200),
    @ContactName    NVARCHAR(200) = NULL,
    @ContactPhone   NVARCHAR(30) = NULL,
    @ContactEmail   NVARCHAR(256) = NULL,
    @Address        NVARCHAR(300) = NULL,
    @BankAccountNo  NVARCHAR(50) = NULL,
    @BankIfscCode   NVARCHAR(20) = NULL,
    @PanNo          NVARCHAR(20) = NULL,
    @GstinNo        NVARCHAR(20) = NULL,
    @IsActive       BIT,
    @ModifiedBy     NVARCHAR(256),
    @IsUpdated      BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE billing.Vendors
        SET Name = @Name, ContactName = @ContactName, ContactPhone = @ContactPhone, ContactEmail = @ContactEmail,
            Address = @Address, BankAccountNo = @BankAccountNo, BankIfscCode = @BankIfscCode,
            PanNo = @PanNo, GstinNo = @GstinNo, IsActive = @IsActive,
            ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @VendorId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.Trips: LEFT JOIN regeneration + ownership fields ==========

IF OBJECT_ID('ops.usp_GetTrips', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTrips;
GO

CREATE PROCEDURE ops.usp_GetTrips
    @FromDate   DATETIME2(3) = NULL,
    @ToDate     DATETIME2(3) = NULL,
    @StatusId   INT = NULL,
    @VehicleId  INT = NULL,
    @DriverId   INT = NULL,
    @RouteId    INT = NULL,
    @PageNumber INT = 1,
    @PageSize   INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            t.Id, t.RouteId, r.Name AS RouteName,
            t.VehicleId, v.RegistrationNo,
            t.DriverId, d.FullName AS DriverName,
            t.ScheduledDeparture, t.ScheduledArrival, t.ActualDeparture, t.ActualArrival,
            t.StatusId, sc.Name AS StatusName,
            t.OwnershipType, t.VendorId, vd.Name AS VendorName,
            t.HiredVehicleNo, t.HiredDriverName, t.HiredDriverPhone, t.VendorFreightAmount,
            COUNT(*) OVER() AS TotalCount
        FROM ops.Trips t
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        LEFT JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        LEFT JOIN fleet.Drivers d ON d.Id = t.DriverId
        LEFT JOIN billing.Vendors vd ON vd.Id = t.VendorId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
        WHERE t.IsDeleted = 0
          AND (@FromDate IS NULL OR t.ScheduledDeparture >= @FromDate)
          AND (@ToDate IS NULL OR t.ScheduledDeparture <= @ToDate)
          AND (@StatusId IS NULL OR t.StatusId = @StatusId)
          AND (@VehicleId IS NULL OR t.VehicleId = @VehicleId)
          AND (@DriverId IS NULL OR t.DriverId = @DriverId)
          AND (@RouteId IS NULL OR t.RouteId = @RouteId)
        ORDER BY t.ScheduledDeparture DESC
        OFFSET (@PageNumber - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_GetTripById', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripById;
GO

CREATE PROCEDURE ops.usp_GetTripById
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            t.Id, t.RouteId, r.Name AS RouteName,
            t.VehicleId, v.RegistrationNo,
            t.DriverId, d.FullName AS DriverName,
            t.ScheduledDeparture, t.ScheduledArrival, t.ActualDeparture, t.ActualArrival,
            t.StatusId, sc.Name AS StatusName,
            t.OwnershipType, t.VendorId, vd.Name AS VendorName,
            t.HiredVehicleNo, t.HiredDriverName, t.HiredDriverPhone, t.VendorFreightAmount
        FROM ops.Trips t
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        LEFT JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        LEFT JOIN fleet.Drivers d ON d.Id = t.DriverId
        LEFT JOIN billing.Vendors vd ON vd.Id = t.VendorId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
        WHERE t.Id = @TripId AND t.IsDeleted = 0;

        SELECT h.Id, h.StatusId, sc.Name AS StatusName, h.ChangedAt, h.Notes
        FROM ops.TripStatusHistory h
        INNER JOIN lookup.StatusCodes sc ON sc.Id = h.StatusId
        WHERE h.TripId = @TripId
        ORDER BY h.ChangedAt;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertTrip', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertTrip;
GO

CREATE PROCEDURE ops.usp_InsertTrip
    @RouteId              INT,
    @ScheduledDeparture   DATETIME2(3),
    @ScheduledArrival     DATETIME2(3),
    @StatusId             INT,
    @OwnershipType        NVARCHAR(10) = 'Own',
    @VehicleId            INT = NULL,
    @DriverId             INT = NULL,
    @VendorId             INT = NULL,
    @HiredVehicleNo       NVARCHAR(30) = NULL,
    @HiredDriverName      NVARCHAR(200) = NULL,
    @HiredDriverPhone     NVARCHAR(30) = NULL,
    @VendorFreightAmount  DECIMAL(18,2) = NULL,
    @CreatedBy            NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO ops.Trips
            (RouteId, VehicleId, DriverId, ScheduledDeparture, ScheduledArrival, StatusId, CreatedBy,
             OwnershipType, VendorId, HiredVehicleNo, HiredDriverName, HiredDriverPhone, VendorFreightAmount)
        VALUES
            (@RouteId, @VehicleId, @DriverId, @ScheduledDeparture, @ScheduledArrival, @StatusId, @CreatedBy,
             @OwnershipType, @VendorId, @HiredVehicleNo, @HiredDriverName, @HiredDriverPhone, @VendorFreightAmount);

        DECLARE @NewTripId INT = SCOPE_IDENTITY();

        INSERT INTO ops.TripStatusHistory (TripId, StatusId, Notes, CreatedBy)
        VALUES (@NewTripId, @StatusId, 'Trip created', @CreatedBy);

        COMMIT TRANSACTION;

        SELECT @NewTripId AS TripId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_UpdateTrip', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_UpdateTrip;
GO

CREATE PROCEDURE ops.usp_UpdateTrip
    @TripId               INT,
    @RouteId              INT,
    @ScheduledDeparture   DATETIME2(3),
    @ScheduledArrival     DATETIME2(3),
    @OwnershipType        NVARCHAR(10) = 'Own',
    @VehicleId            INT = NULL,
    @DriverId             INT = NULL,
    @VendorId             INT = NULL,
    @HiredVehicleNo       NVARCHAR(30) = NULL,
    @HiredDriverName      NVARCHAR(200) = NULL,
    @HiredDriverPhone     NVARCHAR(30) = NULL,
    @VendorFreightAmount  DECIMAL(18,2) = NULL,
    @ModifiedBy           NVARCHAR(256),
    @IsUpdated            BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.Trips
        SET RouteId              = @RouteId,
            VehicleId             = @VehicleId,
            DriverId              = @DriverId,
            ScheduledDeparture    = @ScheduledDeparture,
            ScheduledArrival      = @ScheduledArrival,
            OwnershipType         = @OwnershipType,
            VendorId              = @VendorId,
            HiredVehicleNo        = @HiredVehicleNo,
            HiredDriverName       = @HiredDriverName,
            HiredDriverPhone      = @HiredDriverPhone,
            VendorFreightAmount   = @VendorFreightAmount,
            ModifiedBy            = @ModifiedBy,
            ModifiedAt            = SYSUTCDATETIME()
        WHERE Id = @TripId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.usp_CheckTripConflicts: LEFT JOIN, nullable params ==========
-- A NULL @DriverId/@VehicleId (hired-trip check) naturally matches nothing
-- on that dimension - `t.DriverId = NULL` is never true in T-SQL - so this
-- correctly reports zero driver/vehicle conflicts for a hired trip without
-- any extra special-casing.

IF OBJECT_ID('ops.usp_CheckTripConflicts', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_CheckTripConflicts;
GO

CREATE PROCEDURE ops.usp_CheckTripConflicts
    @DriverId             INT = NULL,
    @VehicleId            INT = NULL,
    @ScheduledDeparture   DATETIME2(3),
    @ScheduledArrival     DATETIME2(3),
    @ExcludeTripId        INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            t.Id, t.RouteId, r.Name AS RouteName, t.VehicleId, v.RegistrationNo,
            t.DriverId, d.FullName AS DriverName,
            t.ScheduledDeparture, t.ScheduledArrival, t.StatusId, sc.Name AS StatusName,
            CASE WHEN t.DriverId = @DriverId THEN 1 ELSE 0 END AS IsDriverConflict,
            CASE WHEN t.VehicleId = @VehicleId THEN 1 ELSE 0 END AS IsVehicleConflict
        FROM ops.Trips t
        INNER JOIN ops.Routes r ON r.Id = t.RouteId
        LEFT JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        LEFT JOIN fleet.Drivers d ON d.Id = t.DriverId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = t.StatusId
        WHERE t.IsDeleted = 0
          AND sc.Name NOT IN ('Cancelled', 'Completed')
          AND ((@DriverId IS NOT NULL AND t.DriverId = @DriverId) OR (@VehicleId IS NOT NULL AND t.VehicleId = @VehicleId))
          AND (@ExcludeTripId IS NULL OR t.Id <> @ExcludeTripId)
          AND t.ScheduledDeparture < @ScheduledArrival
          AND t.ScheduledArrival > @ScheduledDeparture
        ORDER BY t.ScheduledDeparture ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.usp_GetTripCapacityCheck: LEFT JOIN, nullable capacity ==========
-- A hired truck's real capacity isn't tracked in our fleet data, so the
-- check simply can't be performed for a Hired trip - NULL capacity/assigned
-- fields (not 0, which would misleadingly imply "checked, fits fine").

IF OBJECT_ID('ops.usp_GetTripCapacityCheck', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripCapacityCheck;
GO

CREATE PROCEDURE ops.usp_GetTripCapacityCheck
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            @TripId AS TripId,
            v.CapacityKg AS VehicleCapacityKg,
            v.CapacityCbm AS VehicleCapacityCbm,
            CASE WHEN v.Id IS NULL THEN NULL ELSE ISNULL((
                SELECT SUM(si.WeightKg)
                FROM ops.Shipments sh
                INNER JOIN ops.ShipmentItems si ON si.ShipmentId = sh.Id AND si.IsDeleted = 0
                WHERE sh.TripId = @TripId AND sh.IsDeleted = 0
            ), 0) END AS AssignedWeightKg,
            CASE WHEN v.Id IS NULL THEN NULL ELSE ISNULL((
                SELECT SUM(si.VolumeCbm)
                FROM ops.Shipments sh
                INNER JOIN ops.ShipmentItems si ON si.ShipmentId = sh.Id AND si.IsDeleted = 0
                WHERE sh.TripId = @TripId AND sh.IsDeleted = 0
            ), 0) END AS AssignedVolumeCbm
        FROM ops.Trips t
        LEFT JOIN fleet.Vehicles v ON v.Id = t.VehicleId
        WHERE t.Id = @TripId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== fleet.usp_GetFleetUtilisationTrend: exclude Hired-trip hours ==========

IF OBJECT_ID('fleet.usp_GetFleetUtilisationTrend', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetFleetUtilisationTrend;
GO

CREATE PROCEDURE fleet.usp_GetFleetUtilisationTrend
    @MonthsBack INT = 6
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
        DECLARE @StartMonth DATE = DATEFROMPARTS(YEAR(DATEADD(MONTH, 1 - @MonthsBack, @Today)), MONTH(DATEADD(MONTH, 1 - @MonthsBack, @Today)), 1);
        DECLARE @CurrentMonth DATE = DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1);
        DECLARE @VehicleCount INT = (SELECT COUNT(*) FROM fleet.Vehicles WHERE IsDeleted = 0);

        ;WITH Months AS (
            SELECT @StartMonth AS MonthStart
            UNION ALL
            SELECT DATEADD(MONTH, 1, MonthStart)
            FROM Months
            WHERE MonthStart < @CurrentMonth
        )
        SELECT
            FORMAT(m.MonthStart, 'yyyy-MM') AS PeriodLabel,
            CASE
                WHEN @VehicleCount > 0 THEN
                    ROUND(
                        ISNULL(SUM(DATEDIFF(MINUTE, t.ScheduledDeparture, t.ScheduledArrival)), 0) / 60.0
                        / (@VehicleCount * DATEDIFF(HOUR, m.MonthStart, DATEADD(MONTH, 1, m.MonthStart))) * 100,
                        2)
                ELSE 0
            END AS UtilisationPercent
        FROM Months m
        LEFT JOIN ops.Trips t
            ON t.IsDeleted = 0
           -- Hired-truck hours would otherwise inflate OUR fleet's
           -- utilisation% - @VehicleCount (the denominator) only counts
           -- fleet.Vehicles, so the numerator must be scoped the same way.
           AND t.OwnershipType = 'Own'
           AND t.ScheduledDeparture >= m.MonthStart
           AND t.ScheduledDeparture < DATEADD(MONTH, 1, m.MonthStart)
        GROUP BY m.MonthStart
        ORDER BY m.MonthStart
        OPTION (MAXRECURSION 60);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== dbo.usp_GlobalSearch: LEFT JOIN Trip branch ==========

IF OBJECT_ID('dbo.usp_GlobalSearch', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_GlobalSearch;
GO

CREATE PROCEDURE dbo.usp_GlobalSearch
    @SearchTerm NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Like NVARCHAR(206) =
            '%' + REPLACE(REPLACE(REPLACE(@SearchTerm, '[', '[[]'), '%', '[%]'), '_', '[_]') + '%';

        -- Each branch is a derived table (not a bare parenthesized SELECT) -
        -- T-SQL only allows ORDER BY on a UNION member's SELECT when it's
        -- wrapped this way (see 025_global_search_proc.sql's header comment
        -- for the original discovery of this).
        SELECT * FROM (
            SELECT TOP (5) 'Trip' AS EntityType, t.Id AS EntityId, r.Name AS Label,
                   CONCAT(ISNULL(v.RegistrationNo, t.HiredVehicleNo), ' / ', ISNULL(d.FullName, t.HiredDriverName)) AS SubLabel
            FROM ops.Trips t
            INNER JOIN ops.Routes r ON r.Id = t.RouteId
            LEFT JOIN fleet.Vehicles v ON v.Id = t.VehicleId
            LEFT JOIN fleet.Drivers d ON d.Id = t.DriverId
            WHERE t.IsDeleted = 0
                  AND (r.Name LIKE @Like ESCAPE '[' OR v.RegistrationNo LIKE @Like ESCAPE '[' OR d.FullName LIKE @Like ESCAPE '['
                       OR t.HiredVehicleNo LIKE @Like ESCAPE '[' OR t.HiredDriverName LIKE @Like ESCAPE '[')
            ORDER BY r.Name
        ) AS Trips

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Vehicle' AS EntityType, v.Id AS EntityId, v.RegistrationNo AS Label, CONCAT(v.Make, ' ', v.Model) AS SubLabel
            FROM fleet.Vehicles v
            WHERE v.IsDeleted = 0
                  AND (v.RegistrationNo LIKE @Like ESCAPE '[' OR v.Make LIKE @Like ESCAPE '[' OR v.Model LIKE @Like ESCAPE '[')
            ORDER BY v.RegistrationNo
        ) AS Vehicles

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Driver' AS EntityType, d.Id AS EntityId, d.FullName AS Label, ISNULL(d.PhoneNo, d.Email) AS SubLabel
            FROM fleet.Drivers d
            WHERE d.IsDeleted = 0
                  AND (d.FullName LIKE @Like ESCAPE '[' OR d.PhoneNo LIKE @Like ESCAPE '[' OR d.Email LIKE @Like ESCAPE '[')
            ORDER BY d.FullName
        ) AS Drivers

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Shipment' AS EntityType, s.Id AS EntityId, s.TrackingNo AS Label, c.Name AS SubLabel
            FROM ops.Shipments s
            INNER JOIN billing.Customers c ON c.Id = s.CustomerId
            WHERE s.IsDeleted = 0 AND s.TrackingNo LIKE @Like ESCAPE '['
            ORDER BY s.TrackingNo
        ) AS Shipments

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Route' AS EntityType, r.Id AS EntityId, r.Name AS Label, CONCAT(oc.Name, ' -> ', dc.Name) AS SubLabel
            FROM ops.Routes r
            INNER JOIN lookup.Cities oc ON oc.Id = r.OriginCityId
            INNER JOIN lookup.Cities dc ON dc.Id = r.DestinationCityId
            WHERE r.IsDeleted = 0 AND r.Name LIKE @Like ESCAPE '['
            ORDER BY r.Name
        ) AS Routes

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Invoice' AS EntityType, i.Id AS EntityId, i.InvoiceNo AS Label, c.Name AS SubLabel
            FROM billing.Invoices i
            INNER JOIN billing.Customers c ON c.Id = i.CustomerId
            WHERE i.IsDeleted = 0 AND i.InvoiceNo LIKE @Like ESCAPE '['
            ORDER BY i.InvoiceNo
        ) AS Invoices

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'Customer' AS EntityType, c.Id AS EntityId, c.Name AS Label, c.Code AS SubLabel
            FROM billing.Customers c
            WHERE c.IsDeleted = 0 AND (c.Name LIKE @Like ESCAPE '[' OR c.Code LIKE @Like ESCAPE '[')
            ORDER BY c.Name
        ) AS Customers

        UNION ALL

        SELECT * FROM (
            SELECT TOP (5) 'User' AS EntityType, u.Id AS EntityId, u.DisplayName AS Label, u.Email AS SubLabel
            FROM auth.Users u
            WHERE u.IsDeleted = 0
                  AND (u.DisplayName LIKE @Like ESCAPE '[' OR u.Email LIKE @Like ESCAPE '[' OR u.EmpCode LIKE @Like ESCAPE '[')
            ORDER BY u.DisplayName
        ) AS Users

        ORDER BY EntityType, Label;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.VendorAdvances / ops.VendorDeductions ==========

IF OBJECT_ID('ops.usp_GetVendorAdvances', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetVendorAdvances;
GO

CREATE PROCEDURE ops.usp_GetVendorAdvances
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, TripId, VendorId, Amount, AdvanceDate, Remarks, CreatedAt, CreatedBy
        FROM ops.VendorAdvances
        WHERE TripId = @TripId AND IsDeleted = 0
        ORDER BY AdvanceDate;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertVendorAdvance', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertVendorAdvance;
GO

CREATE PROCEDURE ops.usp_InsertVendorAdvance
    @TripId       INT,
    @VendorId     INT,
    @Amount       DECIMAL(18,2),
    @AdvanceDate  DATE,
    @Remarks      NVARCHAR(300) = NULL,
    @CreatedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.VendorAdvances (TripId, VendorId, Amount, AdvanceDate, Remarks, CreatedBy)
        VALUES (@TripId, @VendorId, @Amount, @AdvanceDate, @Remarks, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_DeleteVendorAdvance', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_DeleteVendorAdvance;
GO

CREATE PROCEDURE ops.usp_DeleteVendorAdvance
    @Id           INT,
    @ModifiedBy   NVARCHAR(256),
    @Success      BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.VendorAdvances
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_GetVendorDeductions', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetVendorDeductions;
GO

CREATE PROCEDURE ops.usp_GetVendorDeductions
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, TripId, VendorId, Amount, Reason, DeductionDate, CreatedAt, CreatedBy
        FROM ops.VendorDeductions
        WHERE TripId = @TripId AND IsDeleted = 0
        ORDER BY DeductionDate;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_InsertVendorDeduction', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_InsertVendorDeduction;
GO

CREATE PROCEDURE ops.usp_InsertVendorDeduction
    @TripId         INT,
    @VendorId       INT,
    @Amount         DECIMAL(18,2),
    @Reason         NVARCHAR(300),
    @DeductionDate  DATE,
    @CreatedBy      NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO ops.VendorDeductions (TripId, VendorId, Amount, Reason, DeductionDate, CreatedBy)
        VALUES (@TripId, @VendorId, @Amount, @Reason, @DeductionDate, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('ops.usp_DeleteVendorDeduction', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_DeleteVendorDeduction;
GO

CREATE PROCEDURE ops.usp_DeleteVendorDeduction
    @Id           INT,
    @ModifiedBy   NVARCHAR(256),
    @Success      BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE ops.VendorDeductions
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @Id AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== billing.VendorBills / billing.VendorPayments ==========

IF OBJECT_ID('billing.usp_GetVendorBills', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetVendorBills;
GO

CREATE PROCEDURE billing.usp_GetVendorBills
    @VendorId INT = NULL,
    @StatusId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            vb.Id, vb.VendorId, vd.Name AS VendorName, vb.TripId,
            vb.BillNo, vb.BillDate, vb.DueDate, vb.Amount,
            vb.StatusId, sc.Name AS StatusName,
            ISNULL(p.PaidAmount, 0) AS PaidAmount
        FROM billing.VendorBills vb
        INNER JOIN billing.Vendors vd ON vd.Id = vb.VendorId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = vb.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.VendorPayments pay
            WHERE pay.VendorBillId = vb.Id AND pay.IsDeleted = 0
        ) p
        WHERE vb.IsDeleted = 0
          AND (@VendorId IS NULL OR vb.VendorId = @VendorId)
          AND (@StatusId IS NULL OR vb.StatusId = @StatusId)
        ORDER BY vb.BillDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetVendorBillById', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetVendorBillById;
GO

CREATE PROCEDURE billing.usp_GetVendorBillById
    @VendorBillId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            vb.Id, vb.VendorId, vd.Name AS VendorName, vb.TripId,
            vb.BillNo, vb.BillDate, vb.DueDate, vb.Amount,
            vb.StatusId, sc.Name AS StatusName,
            ISNULL(p.PaidAmount, 0) AS PaidAmount
        FROM billing.VendorBills vb
        INNER JOIN billing.Vendors vd ON vd.Id = vb.VendorId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = vb.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.VendorPayments pay
            WHERE pay.VendorBillId = vb.Id AND pay.IsDeleted = 0
        ) p
        WHERE vb.Id = @VendorBillId AND vb.IsDeleted = 0;

        SELECT Id, PaymentDate, Amount, Method, ReferenceNo
        FROM billing.VendorPayments
        WHERE VendorBillId = @VendorBillId AND IsDeleted = 0
        ORDER BY PaymentDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Amount is computed here (VendorFreightAmount less deductions), not
-- staff-entered - same "derive, don't hand-type, what's already recorded
-- elsewhere" reasoning as invoice Subtotal being SUM(lines). Advances are
-- deliberately NOT subtracted here (see schema file's design note) - they
-- stay a separate, informational ledger; settling them against what's
-- actually still owed is a staff judgment call made when recording
-- VendorPayments, not an automatic reconciliation.
IF OBJECT_ID('billing.usp_InsertVendorBill', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertVendorBill;
GO

CREATE PROCEDURE billing.usp_InsertVendorBill
    @TripId        INT,
    @BillNo        NVARCHAR(50),
    @BillDate      DATE,
    @DueDate       DATE,
    @StatusId      INT,
    @CreatedBy     NVARCHAR(256),
    @Success       BIT OUTPUT,
    @ErrorMessage  NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET @Success = 0;
        SET @ErrorMessage = NULL;

        DECLARE @VendorId INT, @VendorFreightAmount DECIMAL(18,2), @OwnershipType NVARCHAR(10);
        SELECT @VendorId = VendorId, @VendorFreightAmount = VendorFreightAmount, @OwnershipType = OwnershipType
        FROM ops.Trips WHERE Id = @TripId AND IsDeleted = 0;

        IF @OwnershipType IS NULL
        BEGIN
            SET @ErrorMessage = 'Trip not found';
            RETURN;
        END
        IF @OwnershipType <> 'Hired'
        BEGIN
            SET @ErrorMessage = 'Only a Hired trip can be billed by a vendor';
            RETURN;
        END
        IF EXISTS (SELECT 1 FROM billing.VendorBills WHERE TripId = @TripId AND IsDeleted = 0)
        BEGIN
            SET @ErrorMessage = 'This trip already has a vendor bill';
            RETURN;
        END

        DECLARE @Deductions DECIMAL(18,2) = ISNULL((SELECT SUM(Amount) FROM ops.VendorDeductions WHERE TripId = @TripId AND IsDeleted = 0), 0);
        DECLARE @Amount DECIMAL(18,2) = ISNULL(@VendorFreightAmount, 0) - @Deductions;
        IF @Amount < 0 SET @Amount = 0;

        BEGIN TRANSACTION;

        INSERT INTO billing.VendorBills (VendorId, TripId, BillNo, BillDate, DueDate, Amount, StatusId, CreatedBy)
        VALUES (@VendorId, @TripId, @BillNo, @BillDate, @DueDate, @Amount, @StatusId, @CreatedBy);

        DECLARE @NewId INT = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SET @Success = 1;
        SELECT @NewId AS NewId, @Amount AS Amount;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- Mirrors billing.usp_InsertPayment's auto status-transition exactly, just
-- against VendorBills/VendorBill-category codes instead of Invoices/Invoice.
IF OBJECT_ID('billing.usp_InsertVendorPayment', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertVendorPayment;
GO

CREATE PROCEDURE billing.usp_InsertVendorPayment
    @VendorBillId  INT,
    @PaymentDate   DATE,
    @Amount        DECIMAL(18,2),
    @Method        NVARCHAR(50),
    @ReferenceNo   NVARCHAR(100) = NULL,
    @CreatedBy     NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO billing.VendorPayments (VendorBillId, PaymentDate, Amount, Method, ReferenceNo, CreatedBy)
        VALUES (@VendorBillId, @PaymentDate, @Amount, @Method, @ReferenceNo, @CreatedBy);

        DECLARE @NewPaymentId INT = SCOPE_IDENTITY();

        DECLARE @TotalAmount DECIMAL(18,2), @TotalPaid DECIMAL(18,2);
        SELECT @TotalAmount = Amount FROM billing.VendorBills WHERE Id = @VendorBillId;
        SELECT @TotalPaid = ISNULL(SUM(Amount), 0) FROM billing.VendorPayments WHERE VendorBillId = @VendorBillId AND IsDeleted = 0;

        DECLARE @NewStatusName NVARCHAR(50) = CASE
            WHEN @TotalPaid >= @TotalAmount THEN 'Paid'
            WHEN @TotalPaid > 0 THEN 'Partially Paid'
            ELSE NULL
        END;

        IF @NewStatusName IS NOT NULL
        BEGIN
            UPDATE vb
            SET vb.StatusId = sc.Id, vb.ModifiedBy = @CreatedBy, vb.ModifiedAt = SYSUTCDATETIME()
            FROM billing.VendorBills vb
            INNER JOIN lookup.StatusCodes sc ON sc.Category = 'VendorBill' AND sc.Name = @NewStatusName
            WHERE vb.Id = @VendorBillId
              AND vb.StatusId NOT IN (SELECT Id FROM lookup.StatusCodes WHERE Category = 'VendorBill' AND Name = 'Void');
        END

        COMMIT TRANSACTION;

        SELECT @NewPaymentId AS NewId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_DeleteVendorPayment', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_DeleteVendorPayment;
GO

CREATE PROCEDURE billing.usp_DeleteVendorPayment
    @PaymentId    INT,
    @ModifiedBy   NVARCHAR(256),
    @Success      BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @VendorBillId INT;
        SELECT @VendorBillId = VendorBillId FROM billing.VendorPayments WHERE Id = @PaymentId AND IsDeleted = 0;

        UPDATE billing.VendorPayments
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @PaymentId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;

        IF @Success = 1 AND @VendorBillId IS NOT NULL
        BEGIN
            DECLARE @TotalAmount DECIMAL(18,2), @TotalPaid DECIMAL(18,2);
            SELECT @TotalAmount = Amount FROM billing.VendorBills WHERE Id = @VendorBillId;
            SELECT @TotalPaid = ISNULL(SUM(Amount), 0) FROM billing.VendorPayments WHERE VendorBillId = @VendorBillId AND IsDeleted = 0;

            DECLARE @NewStatusName NVARCHAR(50) = CASE
                WHEN @TotalPaid >= @TotalAmount AND @TotalAmount > 0 THEN 'Paid'
                WHEN @TotalPaid > 0 THEN 'Partially Paid'
                ELSE 'Sent'
            END;

            UPDATE vb
            SET vb.StatusId = sc.Id, vb.ModifiedBy = @ModifiedBy, vb.ModifiedAt = SYSUTCDATETIME()
            FROM billing.VendorBills vb
            INNER JOIN lookup.StatusCodes sc ON sc.Category = 'VendorBill' AND sc.Name = @NewStatusName
            WHERE vb.Id = @VendorBillId
              AND vb.StatusId NOT IN (SELECT Id FROM lookup.StatusCodes WHERE Category = 'VendorBill' AND Name = 'Void');
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetVendorOutstandingBalance', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetVendorOutstandingBalance;
GO

CREATE PROCEDURE billing.usp_GetVendorOutstandingBalance
    @VendorId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            @VendorId AS VendorId,
            ISNULL(SUM(vb.Amount - ISNULL(p.PaidAmount, 0)), 0) AS OutstandingBalance
        FROM billing.VendorBills vb
        INNER JOIN lookup.StatusCodes sc ON sc.Id = vb.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.VendorPayments pay
            WHERE pay.VendorBillId = vb.Id AND pay.IsDeleted = 0
        ) p
        WHERE vb.VendorId = @VendorId
          AND vb.IsDeleted = 0
          AND sc.Name NOT IN ('Void', 'Paid');
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Mirrors billing.usp_GetAgingReport's bucket shape for consistency with the
-- existing customer aging report UI pattern.
IF OBJECT_ID('billing.usp_GetVendorAgingReport', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetVendorAgingReport;
GO

CREATE PROCEDURE billing.usp_GetVendorAgingReport
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Today DATE = ISNULL(@AsOfDate, CAST(SYSUTCDATETIME() AS DATE));

        SELECT
            vb.Id, vb.BillNo, vb.VendorId, vd.Name AS VendorName,
            vb.BillDate, vb.DueDate,
            (vb.Amount - ISNULL(p.PaidAmount, 0)) AS OutstandingAmount,
            CASE WHEN @Today > vb.DueDate THEN DATEDIFF(DAY, vb.DueDate, @Today) ELSE 0 END AS DaysOverdue
        FROM billing.VendorBills vb
        INNER JOIN billing.Vendors vd ON vd.Id = vb.VendorId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = vb.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.VendorPayments pay
            WHERE pay.VendorBillId = vb.Id AND pay.IsDeleted = 0
        ) p
        WHERE vb.IsDeleted = 0
          AND sc.Name NOT IN ('Void', 'Paid')
          AND (vb.Amount - ISNULL(p.PaidAmount, 0)) > 0
        ORDER BY DaysOverdue DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== ops.usp_GetTripCostSummary: customer charges + vendor freight (trip profit) ==========

IF OBJECT_ID('ops.usp_GetTripCostSummary', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetTripCostSummary;
GO

CREATE PROCEDURE ops.usp_GetTripCostSummary
    @TripId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            @TripId AS TripId,
            ISNULL((SELECT SUM(Amount) FROM ops.TripExpenses WHERE TripId = @TripId AND IsDeleted = 0), 0) AS TotalExpenses,
            ISNULL((SELECT SUM(Amount) FROM ops.TripAdvances WHERE TripId = @TripId AND IsDeleted = 0), 0) AS TotalAdvances,
            ISNULL((
                SELECT SUM(sc.Amount)
                FROM billing.ShipmentCharges sc
                INNER JOIN ops.Shipments sh ON sh.Id = sc.ShipmentId
                WHERE sh.TripId = @TripId AND sc.IsDeleted = 0
            ), 0) AS CustomerChargesTotal,
            t.VendorFreightAmount
        FROM ops.Trips t
        WHERE t.Id = @TripId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
