/*
  Purpose:      Seed data for Invoices + InvoiceLines (~10 invoices, 1-2
                lines each). Dates are fixed literals, not SYSUTCDATETIME(),
                so re-running this script stays idempotent across days.
  Author:       TransitCore rebuild
  Date:         2026-09-11
  Dependencies: 005_billing_customers_seed.sql, 009_billing_invoicing_schema.sql,
                010_billing_tvp.sql
*/
SET NOCOUNT ON;
GO

DECLARE @Draft   INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Code = 'DRAFT');
DECLARE @Sent    INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Code = 'SENT');
DECLARE @Paid    INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Code = 'PAID');
DECLARE @Partial INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Code = 'PARTIALLY_PAID');
DECLARE @Overdue INT = (SELECT Id FROM lookup.StatusCodes WHERE Category = 'Invoice' AND Code = 'OVERDUE');

INSERT INTO billing.Invoices (InvoiceNo, CustomerId, InvoiceDate, DueDate, Subtotal, TaxAmount, TotalAmount, StatusId, CreatedBy)
SELECT i.InvoiceNo, c.Id, i.InvoiceDate, i.DueDate, i.Subtotal, i.TaxAmount, i.Subtotal + i.TaxAmount, i.StatusId, 'seed'
FROM (VALUES
    ('INV-2026-0001', 'CUST001', '2026-08-01', '2026-08-31', 45000.00, 8100.00, @Paid),
    ('INV-2026-0002', 'CUST002', '2026-08-03', '2026-09-02', 62000.00, 11160.00, @Paid),
    ('INV-2026-0003', 'CUST003', '2026-08-10', '2026-09-09', 38000.00, 6840.00, @Partial),
    ('INV-2026-0004', 'CUST004', '2026-08-15', '2026-09-14', 51000.00, 9180.00, @Sent),
    ('INV-2026-0005', 'CUST005', '2026-08-20', '2026-09-19', 29500.00, 5310.00, @Sent),
    ('INV-2026-0006', 'CUST006', '2026-08-22', '2026-09-21', 73000.00, 13140.00, @Overdue),
    ('INV-2026-0007', 'CUST007', '2026-08-25', '2026-09-24', 41000.00, 7380.00, @Sent),
    ('INV-2026-0008', 'CUST008', '2026-09-01', '2026-10-01', 55500.00, 9990.00, @Draft),
    ('INV-2026-0009', 'CUST009', '2026-09-03', '2026-10-03', 33000.00, 5940.00, @Sent),
    ('INV-2026-0010', 'CUST010', '2026-09-05', '2026-10-05', 48000.00, 8640.00, @Draft)
) AS i (InvoiceNo, CustomerCode, InvoiceDate, DueDate, Subtotal, TaxAmount, StatusId)
INNER JOIN billing.Customers c ON c.Code = i.CustomerCode
WHERE NOT EXISTS (SELECT 1 FROM billing.Invoices ex WHERE ex.InvoiceNo = i.InvoiceNo);
GO

INSERT INTO billing.InvoiceLines (InvoiceId, Description, Quantity, UnitPrice, LineTotal, CreatedBy)
SELECT inv.Id, l.Description, l.Quantity, l.UnitPrice, l.Quantity * l.UnitPrice, 'seed'
FROM (VALUES
    ('INV-2026-0001', 'Freight charges - Mumbai to Delhi', 1, 45000.00),
    ('INV-2026-0002', 'Freight charges - bulk shipment',   1, 62000.00),
    ('INV-2026-0003', 'Freight charges - Chennai route',   1, 38000.00),
    ('INV-2026-0004', 'Freight charges - Pune to Ahmedabad',1, 51000.00),
    ('INV-2026-0005', 'Freight charges - regional delivery',1, 29500.00),
    ('INV-2026-0006', 'Freight charges - express service',  1, 73000.00),
    ('INV-2026-0007', 'Freight charges - Hyderabad route',   1, 41000.00),
    ('INV-2026-0008', 'Freight charges - scheduled delivery',1, 55500.00),
    ('INV-2026-0009', 'Freight charges - Kolkata route',     1, 33000.00),
    ('INV-2026-0010', 'Freight charges - Jaipur route',      1, 48000.00)
) AS l (InvoiceNo, Description, Quantity, UnitPrice)
INNER JOIN billing.Invoices inv ON inv.InvoiceNo = l.InvoiceNo
WHERE NOT EXISTS (SELECT 1 FROM billing.InvoiceLines ex WHERE ex.InvoiceId = inv.Id);
GO

-- Payments for the Paid/Partially-Paid invoices, so usp_GetInvoiceSummary
-- has a non-zero TotalPaid to show.
INSERT INTO billing.Payments (InvoiceId, PaymentDate, Amount, Method, ReferenceNo, CreatedBy)
SELECT inv.Id, p.PaymentDate, p.Amount, p.Method, p.ReferenceNo, 'seed'
FROM (VALUES
    ('INV-2026-0001', '2026-08-10', 53100.00, 'Bank Transfer', 'PMT-0001'),
    ('INV-2026-0002', '2026-08-12', 73160.00, 'Bank Transfer', 'PMT-0002'),
    ('INV-2026-0003', '2026-08-25', 20000.00, 'Cheque',        'PMT-0003')
) AS p (InvoiceNo, PaymentDate, Amount, Method, ReferenceNo)
INNER JOIN billing.Invoices inv ON inv.InvoiceNo = p.InvoiceNo
WHERE NOT EXISTS (SELECT 1 FROM billing.Payments ex WHERE ex.ReferenceNo = p.ReferenceNo);
GO
