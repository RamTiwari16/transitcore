/*
  Purpose:      Billing domain procedures - customer CRUD, invoice
                listing/detail/insert (with lines TVP, explicit
                transaction), and the invoice summary heavy read path.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 007_billing_customers_schema.sql, 009_billing_invoicing_schema.sql,
                010_billing_tvp.sql
*/
-- Procs keep the QUOTED_IDENTIFIER setting they were created with; tables with filtered indexes reject writes from procs created with it OFF.
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
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
        SELECT Id, Code, Name, IsActive
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

IF OBJECT_ID('billing.usp_InsertCustomer', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_InsertCustomer;
GO

CREATE PROCEDURE billing.usp_InsertCustomer
    @Code       NVARCHAR(50),
    @Name       NVARCHAR(200),
    @CreatedBy  NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO billing.Customers (Code, Name, CreatedBy)
        VALUES (@Code, @Name, @CreatedBy);

        SELECT CAST(SCOPE_IDENTITY() AS INT) AS CustomerId;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO

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
            i.InvoiceDate, i.DueDate, i.Subtotal, i.TaxAmount, i.TotalAmount,
            i.StatusId, sc.Name AS StatusName
        FROM billing.Invoices i
        INNER JOIN billing.Customers c ON c.Id = i.CustomerId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
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
            i.InvoiceDate, i.DueDate, i.Subtotal, i.TaxAmount, i.TotalAmount,
            i.StatusId, sc.Name AS StatusName
        FROM billing.Invoices i
        INNER JOIN billing.Customers c ON c.Id = i.CustomerId
        INNER JOIN lookup.StatusCodes sc ON sc.Id = i.StatusId
        WHERE i.Id = @InvoiceId AND i.IsDeleted = 0;

        SELECT Id, ShipmentId, Description, Quantity, UnitPrice, LineTotal
        FROM billing.InvoiceLines
        WHERE InvoiceId = @InvoiceId AND IsDeleted = 0;
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
    @InvoiceNo    NVARCHAR(50),
    @CustomerId   INT,
    @InvoiceDate  DATE,
    @DueDate      DATE,
    @TaxAmount    DECIMAL(18,2),
    @StatusId     INT,
    @CreatedBy    NVARCHAR(256),
    @Lines        billing.InvoiceLineType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Subtotal DECIMAL(18,2) = (SELECT ISNULL(SUM(LineTotal), 0) FROM @Lines);
        DECLARE @Total DECIMAL(18,2) = @Subtotal + @TaxAmount;

        INSERT INTO billing.Invoices
            (InvoiceNo, CustomerId, InvoiceDate, DueDate, Subtotal, TaxAmount, TotalAmount, StatusId, CreatedBy)
        VALUES
            (@InvoiceNo, @CustomerId, @InvoiceDate, @DueDate, @Subtotal, @TaxAmount, @Total, @StatusId, @CreatedBy);

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

/*
  Heavy read path: invoice summary over a date range, optionally scoped to
  one customer. Aggregates invoiced/paid/outstanding so the UI can render a
  billing dashboard without pulling every invoice row client-side.
*/
IF OBJECT_ID('billing.usp_GetInvoiceSummary', 'P') IS NOT NULL
    DROP PROCEDURE billing.usp_GetInvoiceSummary;
GO

CREATE PROCEDURE billing.usp_GetInvoiceSummary
    @FromDate   DATE,
    @ToDate     DATE,
    @CustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT
            COUNT(DISTINCT i.Id) AS InvoiceCount,
            ISNULL(SUM(i.TotalAmount), 0) AS TotalInvoiced,
            ISNULL(SUM(p.PaidAmount), 0) AS TotalPaid,
            ISNULL(SUM(i.TotalAmount), 0) - ISNULL(SUM(p.PaidAmount), 0) AS TotalOutstanding
        FROM billing.Invoices i
        OUTER APPLY (
            SELECT SUM(pay.Amount) AS PaidAmount
            FROM billing.Payments pay
            WHERE pay.InvoiceId = i.Id AND pay.IsDeleted = 0
        ) p
        WHERE i.IsDeleted = 0
          AND i.InvoiceDate BETWEEN @FromDate AND @ToDate
          AND (@CustomerId IS NULL OR i.CustomerId = @CustomerId);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
