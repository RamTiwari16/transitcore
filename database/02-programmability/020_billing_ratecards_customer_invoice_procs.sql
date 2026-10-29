/*
  Purpose:      Phase 4 (Billing depth) - rate cards CRUD, uninvoiced-
                shipments lookup (feeds "generate invoice from shipments"),
                and regenerated customer/invoice procs carrying the new
                CreditLimit and DiscountAmount columns.
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 01-schema/013_billing_phase4_schema.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO

-- ========== billing.RateCards ==========

IF OBJECT_ID('billing.usp_GetRateCards', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetRateCards;
GO

CREATE PROCEDURE billing.usp_GetRateCards
    @CustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            r.Id, r.CustomerId, c.Name AS CustomerName,
            r.OriginCityId, oc.Name AS OriginCityName,
            r.DestinationCityId, dc.Name AS DestinationCityName,
            r.RatePerKg, r.RatePerKm, r.EffectiveFrom, r.EffectiveTo
        FROM billing.RateCards r
        LEFT JOIN billing.Customers c ON c.Id = r.CustomerId
        LEFT JOIN lookup.Cities oc ON oc.Id = r.OriginCityId
        LEFT JOIN lookup.Cities dc ON dc.Id = r.DestinationCityId
        WHERE r.IsDeleted = 0
          AND (@CustomerId IS NULL OR r.CustomerId = @CustomerId OR r.CustomerId IS NULL)
        ORDER BY r.EffectiveFrom DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_InsertRateCard', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertRateCard;
GO

CREATE PROCEDURE billing.usp_InsertRateCard
    @CustomerId         INT = NULL,
    @OriginCityId       INT = NULL,
    @DestinationCityId  INT = NULL,
    @RatePerKg          DECIMAL(18,2) = 0,
    @RatePerKm          DECIMAL(18,2) = 0,
    @EffectiveFrom      DATE,
    @EffectiveTo        DATE = NULL,
    @CreatedBy          NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO billing.RateCards
            (CustomerId, OriginCityId, DestinationCityId, RatePerKg, RatePerKm, EffectiveFrom, EffectiveTo, CreatedBy)
        VALUES
            (@CustomerId, @OriginCityId, @DestinationCityId, @RatePerKg, @RatePerKm, @EffectiveFrom, @EffectiveTo, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS NewId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_DeleteRateCard', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_DeleteRateCard;
GO

CREATE PROCEDURE billing.usp_DeleteRateCard
    @RateCardId  INT,
    @ModifiedBy  NVARCHAR(256),
    @Success     BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE billing.RateCards
        SET IsDeleted = 1, ModifiedBy = @ModifiedBy, ModifiedAt = SYSUTCDATETIME()
        WHERE Id = @RateCardId AND IsDeleted = 0;

        SET @Success = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Uninvoiced shipments (feeds "generate invoice") ==========
-- A shipment is "uninvoiced" if no non-deleted InvoiceLines row references
-- it yet. Returns enough (weight, and the linked trip's route distance if
-- any) for the API layer to price each one against the customer's rate
-- cards - that matching logic lives in C#, not here, since "most specific
-- rate card wins" is business logic that reads better outside T-SQL.
IF OBJECT_ID('billing.usp_GetUninvoicedShipments', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetUninvoicedShipments;
GO

CREATE PROCEDURE billing.usp_GetUninvoicedShipments
    @CustomerId  INT,
    @FromDate    DATE,
    @ToDate      DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            sh.Id, sh.TrackingNo, sh.OriginCityId, oc.Name AS OriginCityName,
            sh.DestinationCityId, dc.Name AS DestinationCityName,
            sh.ShipmentDate,
            ISNULL((SELECT SUM(si.WeightKg) FROM ops.ShipmentItems si WHERE si.ShipmentId = sh.Id AND si.IsDeleted = 0), 0) AS TotalWeightKg,
            r.DistanceKm AS RouteDistanceKm
        FROM ops.Shipments sh
        INNER JOIN lookup.Cities oc ON oc.Id = sh.OriginCityId
        INNER JOIN lookup.Cities dc ON dc.Id = sh.DestinationCityId
        LEFT JOIN ops.Trips t ON t.Id = sh.TripId AND t.IsDeleted = 0
        LEFT JOIN ops.Routes r ON r.Id = t.RouteId
        WHERE sh.CustomerId = @CustomerId
          AND sh.IsDeleted = 0
          AND sh.ShipmentDate BETWEEN @FromDate AND @ToDate
          AND NOT EXISTS (
              SELECT 1 FROM billing.InvoiceLines il
              WHERE il.ShipmentId = sh.Id AND il.IsDeleted = 0
          )
        ORDER BY sh.ShipmentDate ASC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Regenerated: customers (now with CreditLimit) ==========

IF OBJECT_ID('billing.usp_InsertCustomer', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertCustomer;
GO

CREATE PROCEDURE billing.usp_InsertCustomer
    @Code         NVARCHAR(50),
    @Name         NVARCHAR(200),
    @CreditLimit  DECIMAL(18,2) = NULL,
    @CreatedBy    NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO billing.Customers (Code, Name, CreditLimit, CreatedBy)
        VALUES (@Code, @Name, @CreditLimit, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS CustomerId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetCustomers', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetCustomers;
GO

CREATE PROCEDURE billing.usp_GetCustomers
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Code, Name, IsActive, CreditLimit
        FROM billing.Customers
        WHERE IsDeleted = 0
          AND (@ActiveOnly = 0 OR IsActive = 1)
        ORDER BY Name;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetCustomerById', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetCustomerById;
GO

CREATE PROCEDURE billing.usp_GetCustomerById
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT Id, Code, Name, IsActive, CreditLimit
        FROM billing.Customers
        WHERE Id = @CustomerId AND IsDeleted = 0;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_UpdateCustomer', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_UpdateCustomer;
GO

CREATE PROCEDURE billing.usp_UpdateCustomer
    @CustomerId   INT,
    @Name         NVARCHAR(200),
    @IsActive     BIT,
    @CreditLimit  DECIMAL(18,2) = NULL,
    @ModifiedBy   NVARCHAR(256),
    @IsUpdated    BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        UPDATE billing.Customers
        SET Name         = @Name,
            IsActive      = @IsActive,
            CreditLimit   = @CreditLimit,
            ModifiedBy    = @ModifiedBy,
            ModifiedAt    = SYSUTCDATETIME()
        WHERE Id = @CustomerId AND IsDeleted = 0;

        SET @IsUpdated = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- Outstanding balance across every non-void invoice for a customer - used
-- to warn against a credit limit before creating a new invoice/shipment.
IF OBJECT_ID('billing.usp_GetCustomerOutstandingBalance', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetCustomerOutstandingBalance;
GO

CREATE PROCEDURE billing.usp_GetCustomerOutstandingBalance
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            @CustomerId AS CustomerId,
            ISNULL(SUM(i.TotalAmount - ISNULL(p.PaidAmount, 0)), 0) AS OutstandingBalance
        FROM billing.Invoices i
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.CustomerId = @CustomerId
          AND i.IsDeleted = 0
          AND sc.Name NOT IN ('Void', 'Paid');
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

-- ========== Regenerated: invoices (now with DiscountAmount) ==========

IF OBJECT_ID('billing.usp_GetInvoices', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetInvoices;
GO

CREATE PROCEDURE billing.usp_GetInvoices
    @CustomerId INT = NULL,
    @StatusId   INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            i.Id, i.InvoiceNo, i.CustomerId, c.Name AS CustomerName,
            i.InvoiceDate, i.DueDate, i.Subtotal, i.DiscountAmount, i.TaxAmount, i.TotalAmount,
            i.StatusId, sc.Name AS StatusName,
            ISNULL(p.PaidAmount, 0) AS PaidAmount
        FROM billing.Invoices i
        INNER JOIN billing.Customers c ON c.Id = i.CustomerId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.IsDeleted = 0
          AND (@CustomerId IS NULL OR i.CustomerId = @CustomerId)
          AND (@StatusId IS NULL OR i.StatusId = @StatusId)
        ORDER BY i.InvoiceDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_GetInvoiceById', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetInvoiceById;
GO

CREATE PROCEDURE billing.usp_GetInvoiceById
    @InvoiceId INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            i.Id, i.InvoiceNo, i.CustomerId, c.Name AS CustomerName,
            i.InvoiceDate, i.DueDate, i.Subtotal, i.DiscountAmount, i.TaxAmount, i.TotalAmount,
            i.StatusId, sc.Name AS StatusName,
            ISNULL(p.PaidAmount, 0) AS PaidAmount
        FROM billing.Invoices i
        INNER JOIN billing.Customers c ON c.Id = i.CustomerId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.Id = @InvoiceId AND i.IsDeleted = 0;

        SELECT Id, ShipmentId, Description, Quantity, UnitPrice, LineTotal
        FROM billing.InvoiceLines
        WHERE InvoiceId = @InvoiceId AND IsDeleted = 0;

        SELECT Id, PaymentDate, Amount, Method, ReferenceNo
        FROM billing.Payments
        WHERE InvoiceId = @InvoiceId AND IsDeleted = 0
        ORDER BY PaymentDate DESC;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

IF OBJECT_ID('billing.usp_InsertInvoice', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertInvoice;
GO

CREATE PROCEDURE billing.usp_InsertInvoice
    @InvoiceNo       NVARCHAR(50),
    @CustomerId      INT,
    @InvoiceDate     DATE,
    @DueDate         DATE,
    @DiscountAmount  DECIMAL(18,2) = 0,
    @TaxAmount       DECIMAL(18,2),
    @StatusId        INT,
    @CreatedBy       NVARCHAR(256),
    @Lines           billing.InvoiceLineType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF EXISTS (
            SELECT 1
            FROM @Lines l
            INNER JOIN ops.Shipments s ON s.Id = l.ShipmentId
            WHERE s.CustomerId <> @CustomerId
        )
            THROW 50002, 'One or more shipments on this invoice belong to a different customer.', 1;

        BEGIN TRANSACTION;

        DECLARE @Subtotal DECIMAL(18,2) = (SELECT ISNULL(SUM(LineTotal), 0) FROM @Lines);
        DECLARE @Total DECIMAL(18,2) = @Subtotal - @DiscountAmount + @TaxAmount;

        INSERT INTO billing.Invoices
            (InvoiceNo, CustomerId, InvoiceDate, DueDate, Subtotal, DiscountAmount, TaxAmount, TotalAmount, StatusId, CreatedBy)
        VALUES
            (@InvoiceNo, @CustomerId, @InvoiceDate, @DueDate, @Subtotal, @DiscountAmount, @TaxAmount, @Total, @StatusId, @CreatedBy);

        DECLARE @NewInvoiceId INT = SCOPE_IDENTITY();

        INSERT INTO billing.InvoiceLines (InvoiceId, ShipmentId, Description, Quantity, UnitPrice, LineTotal, CreatedBy)
        SELECT @NewInvoiceId, ShipmentId, Description, Quantity, UnitPrice, LineTotal, @CreatedBy
        FROM @Lines;

        COMMIT TRANSACTION;

        SELECT @NewInvoiceId AS InvoiceId;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
