/*
  Purpose:      Phase 4 (Billing depth) schema additions. RateCards and
                Payments already existed unused from the original schema -
                usp_GetInvoiceSummary even already joined against Payments -
                so this file only adds the two columns that were genuinely
                missing: a customer credit limit, and an invoice-level
                discount (Invoices already had Subtotal/TaxAmount/TotalAmount
                but nothing for a discount to sit between them).
  Author:       TransitCore rebuild
  Date:         2026-09-16
  Dependencies: 007_billing_customers_schema.sql, 009_billing_invoicing_schema.sql
*/
SET NOCOUNT ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('billing.Customers') AND name = 'CreditLimit')
BEGIN
    ALTER TABLE billing.Customers ADD CreditLimit DECIMAL(18,2) NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('billing.Invoices') AND name = 'DiscountAmount')
BEGIN
    ALTER TABLE billing.Invoices ADD DiscountAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_Invoices_DiscountAmount DEFAULT 0;
END
GO
