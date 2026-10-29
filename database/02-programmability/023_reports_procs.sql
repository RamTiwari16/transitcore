/*
  Purpose:      Phase 5 (Reports) - cross-cutting aggregate reports not tied
                to a single entity: revenue by period, cross-driver
                settlement summary, fleet utilisation trend, shipment volume
                trend.
  Author:       TransitCore rebuild
  Date:         2026-09-15
  Dependencies: 009_billing_invoicing_schema.sql, 006_fleet_schema.sql,
                008_ops_routes_trips_shipments_schema.sql,
                015_trip_expenses_advances_procs.sql (ops.TripAdvances/TripExpenses)
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- Revenue invoiced vs collected, grouped by calendar month. Sparse: a month
-- with no invoices simply has no row (left to the caller to zero-fill for
-- charting, same tradeoff the existing dashboard chart data takes).
IF OBJECT_ID('billing.usp_GetRevenueByPeriod', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetRevenueByPeriod;
GO

CREATE PROCEDURE billing.usp_GetRevenueByPeriod
    @MonthsBack INT = 12
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
        DECLARE @FromDate DATE = DATEFROMPARTS(YEAR(DATEADD(MONTH, 1 - @MonthsBack, @Today)), MONTH(DATEADD(MONTH, 1 - @MonthsBack, @Today)), 1);

        SELECT
            FORMAT(i.InvoiceDate, 'yyyy-MM') AS PeriodLabel,
            SUM(i.TotalAmount) AS TotalInvoiced,
            SUM(ISNULL(p.PaidAmount, 0)) AS TotalCollected
        FROM billing.Invoices i
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.IsDeleted = 0
          AND i.InvoiceDate >= @FromDate
        GROUP BY FORMAT(i.InvoiceDate, 'yyyy-MM')
        ORDER BY PeriodLabel;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Every driver's lifetime advances/expenses/balance in one call (the
-- single-driver version, fleet.usp_GetDriverSettlement, already backs the
-- Driver Detail "Settlement" tab). Includes drivers with zero activity so
-- nothing is silently hidden from an admin audit view.
IF OBJECT_ID('fleet.usp_GetDriverSettlementSummary', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetDriverSettlementSummary;
GO

CREATE PROCEDURE fleet.usp_GetDriverSettlementSummary
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            d.Id AS DriverId,
            d.FullName,
            ISNULL(adv.TotalAdvances, 0) AS TotalAdvances,
            ISNULL(exp.TotalExpenses, 0) AS TotalExpenses,
            ISNULL(adv.TotalAdvances, 0) - ISNULL(exp.TotalExpenses, 0) AS Balance
        FROM fleet.Drivers d
        OUTER APPLY (
            SELECT SUM(a.Amount) AS TotalAdvances
            FROM ops.TripAdvances a
            INNER JOIN ops.Trips t ON t.Id = a.TripId
            WHERE t.DriverId = d.Id AND a.IsDeleted = 0 AND t.IsDeleted = 0
        ) adv
        OUTER APPLY (
            SELECT SUM(e.Amount) AS TotalExpenses
            FROM ops.TripExpenses e
            INNER JOIN ops.Trips t ON t.Id = e.TripId
            WHERE t.DriverId = d.Id AND e.IsDeleted = 0 AND t.IsDeleted = 0
        ) exp
        WHERE d.IsDeleted = 0
        ORDER BY Balance ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Fleet-wide utilisation percent per calendar month (scheduled trip hours /
-- available hours across the whole active fleet) - a monthly-trend version
-- of fleet.usp_GetFleetUtilisation, which is per-vehicle for one date range.
-- Zero-fills every month in range (unlike the other two reports here) since
-- a gap would otherwise misread as "no data" instead of "0% utilised".
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

-- Shipment count per calendar month. Sparse, same tradeoff as revenue above.
IF OBJECT_ID('ops.usp_GetShipmentVolumeTrend', 'P') IS NOT NULL
    DROP PROCEDURE ops.usp_GetShipmentVolumeTrend;
GO

CREATE PROCEDURE ops.usp_GetShipmentVolumeTrend
    @MonthsBack INT = 12
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);
        DECLARE @FromDate DATE = DATEFROMPARTS(YEAR(DATEADD(MONTH, 1 - @MonthsBack, @Today)), MONTH(DATEADD(MONTH, 1 - @MonthsBack, @Today)), 1);

        SELECT
            FORMAT(s.ShipmentDate, 'yyyy-MM') AS PeriodLabel,
            COUNT(*) AS ShipmentCount
        FROM ops.Shipments s
        WHERE s.IsDeleted = 0
          AND s.ShipmentDate >= @FromDate
        GROUP BY FORMAT(s.ShipmentDate, 'yyyy-MM')
        ORDER BY PeriodLabel;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
