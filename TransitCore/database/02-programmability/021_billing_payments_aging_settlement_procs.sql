/*
  Purpose:      Phase 4 (Billing depth) - payments/receipts (auto-transitions
                the invoice to Partially Paid / Paid as payments cover more
                of the total - both statuses already existed in
                lookup.StatusCodes, unused, from the original seed), an AR
                aging report, and driver settlement (advances vs expenses
                across ALL of a driver's trips - the fleet-wide counterpart
                to fleet.usp_GetDriverPerformance from Phase 2, built on the
                same ops.TripAdvances/TripExpenses tables Phase 3 added).
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 01-schema/013_billing_phase4_schema.sql,
                02-programmability/013_vehicle_documents_maintenance_fuel_procs.sql (schema only, no dependency),
                015_trip_expenses_advances_procs.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO

-- ========== billing.Payments ==========

IF OBJECT_ID('billing.usp_InsertPayment', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertPayment;
GO

CREATE PROCEDURE billing.usp_InsertPayment
    @InvoiceId    INT,
    @PaymentDate  DATE,
    @Amount       DECIMAL(18,2),
    @Method       NVARCHAR(50),
    @ReferenceNo  NVARCHAR(100) = NULL,
    @CreatedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO billing.Payments (InvoiceId, PaymentDate, Amount, Method, ReferenceNo, CreatedBy)
        VALUES (@InvoiceId, @PaymentDate, @Amount, @Method, @ReferenceNo, @CreatedBy);

        DECLARE @NewPaymentId INT = SCOPE_IDENTITY();

        DECLARE @TotalAmount DECIMAL(18,2), @TotalPaid DECIMAL(18,2);
        SELECT @TotalAmount = TotalAmount FROM billing.Invoices WHERE Id = @InvoiceId;
        SELECT @TotalPaid = ISNULL(SUM(Amount), 0) FROM billing.Payments WHERE InvoiceId = @InvoiceId AND IsDeleted = 0;

        DECLARE @NewStatusName NVARCHAR(50) = CASE
            WHEN @TotalPaid >= @TotalAmount THEN 'Paid'
            WHEN @TotalPaid > 0 THEN 'Partially Paid'
            ELSE NULL
        END;

        IF @NewStatusName IS NOT NULL
        BEGIN
            UPDATE i
            SET i.StatusId = sc.Id, i.ModifiedBy = @CreatedBy, i.ModifiedAt = SYSUTCDATETIME()
            FROM billing.Invoices i
            INNER JOIN lookup.StatusCodes sc ON sc.Category = 'Invoice' AND sc.Name = @NewStatusName
            WHERE i.Id = @InvoiceId
              -- Never downgrade a Void invoice back to a payment-derived status.
              AND i.StatusId NOT IN (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Name = 'Void');
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

IF OBJECT_ID('billing.usp_DeletePayment', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_DeletePayment;
GO

CREATE PROCEDURE billing.usp_DeletePayment
    @PaymentId   INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @InvoiceId INT;
        SELECT @InvoiceId = InvoiceId FROM billing.Payments WHERE Id = @PaymentId AND IsDeleted = 0;

        UPDATE billing.Payments
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @PaymentId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;

        -- Re-evaluate status downward too (e.g. a Paid invoice whose only
        -- payment gets removed by mistake should fall back to Sent, not
        -- stay stuck showing Paid) - same three-way rule as on insert.
        IF @Success = 1 AND @InvoiceId IS NOT NULL
        BEGIN
            DECLARE @TotalAmount DECIMAL(18,2), @TotalPaid DECIMAL(18,2);
            SELECT @TotalAmount = TotalAmount FROM billing.Invoices WHERE Id = @InvoiceId;
            SELECT @TotalPaid = ISNULL(SUM(Amount), 0) FROM billing.Payments WHERE InvoiceId = @InvoiceId AND IsDeleted = 0;

            DECLARE @NewStatusName NVARCHAR(50) = CASE
                WHEN @TotalPaid >= @TotalAmount AND @TotalAmount > 0 THEN 'Paid'
                WHEN @TotalPaid > 0 THEN 'Partially Paid'
                ELSE 'Sent'
            END;

            UPDATE i
            SET i.StatusId = sc.Id, i.ModifiedBy = @ModifiedBy, i.ModifiedAt = SYSUTCDATETIME()
            FROM billing.Invoices i
            INNER JOIN lookup.StatusCodes sc ON sc.Category = 'Invoice' AND sc.Name = @NewStatusName
            WHERE i.Id = @InvoiceId
              AND i.StatusId NOT IN (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Name = 'Void');
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

-- ========== AR aging report ==========

IF OBJECT_ID('billing.usp_GetAgingReport', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetAgingReport;
GO

CREATE PROCEDURE billing.usp_GetAgingReport
    @AsOfDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @Today DATE = ISNULL(@AsOfDate, CAST(SYSUTCDATETIME() AS DATE));

        SELECT
            i.Id, i.InvoiceNo, i.CustomerId, c.Name AS CustomerName,
            i.InvoiceDate, i.DueDate,
            i.TotalAmount - ISNULL(p.PaidAmount, 0) AS OutstandingAmount,
            DATEDIFF(DAY, i.DueDate, @Today) AS DaysOverdue
        FROM billing.Invoices i
        INNER JOIN billing.Customers c ON c.Id = i.CustomerId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.IsDeleted = 0
          AND sc.Name NOT IN ('Void', 'Paid')
          AND (i.TotalAmount - ISNULL(p.PaidAmount, 0)) > 0
        ORDER BY DaysOverdue DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Driver settlement (fleet-wide, across all trips) ==========

IF OBJECT_ID('fleet.usp_GetDriverSettlement', 'P') IS NOT NULL
    DROP PROCEDURE fleet.usp_GetDriverSettlement;
GO

CREATE PROCEDURE fleet.usp_GetDriverSettlement
    @DriverId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            @DriverId AS DriverId,
            ISNULL((
                SELECT SUM(a.Amount)
                FROM ops.TripAdvances a
                INNER JOIN ops.Trips t ON t.Id = a.TripId
                WHERE t.DriverId = @DriverId AND a.IsDeleted = 0 AND t.IsDeleted = 0
            ), 0) AS TotalAdvances,
            ISNULL((
                SELECT SUM(e.Amount)
                FROM ops.TripExpenses e
                INNER JOIN ops.Trips t ON t.Id = e.TripId
                WHERE t.DriverId = @DriverId AND e.IsDeleted = 0 AND t.IsDeleted = 0
            ), 0) AS TotalExpenses,
            (
                SELECT COUNT(DISTINCT t.Id)
                FROM ops.Trips t
                WHERE t.DriverId = @DriverId AND t.IsDeleted = 0
                  AND (EXISTS (SELECT 1 FROM ops.TripAdvances a WHERE a.TripId = t.Id AND a.IsDeleted = 0)
                    OR EXISTS (SELECT 1 FROM ops.TripExpenses e WHERE e.TripId = t.Id AND e.IsDeleted = 0))
            ) AS TripsWithActivity;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
