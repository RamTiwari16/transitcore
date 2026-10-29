/*
  Purpose:      Table-valued parameter type for passing invoice lines into
                billing.usp_InsertInvoice.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 009_billing_invoicing_schema.sql
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.types WHERE name = 'InvoiceLineType' AND schema_id = SCHEMA_ID('billing'))
BEGIN
    CREATE TYPE billing.InvoiceLineType AS TABLE
    (
        ShipmentId  INT           NULL,
        Description NVARCHAR(300) NOT NULL,
        Quantity    DECIMAL(18,2) NOT NULL,
        UnitPrice   DECIMAL(18,2) NOT NULL,
        LineTotal   DECIMAL(18,2) NOT NULL
    );
END
GO
