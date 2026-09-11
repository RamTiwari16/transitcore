namespace TransitCore.Application.Models;

public class CustomerDto
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; }
}

public class CreateCustomerRequest
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
}

public class InvoiceFilterRequest
{
    public int? CustomerId { get; set; }
    public int? StatusId { get; set; }
}

public class InvoiceDto
{
    public int Id { get; set; }
    public string InvoiceNo { get; set; } = string.Empty;
    public int CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public DateOnly InvoiceDate { get; set; }
    public DateOnly DueDate { get; set; }
    public decimal Subtotal { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal TotalAmount { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
}

public class InvoiceLineDto
{
    public int Id { get; set; }
    public int? ShipmentId { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
}

public class InvoiceDetailDto : InvoiceDto
{
    public IReadOnlyList<InvoiceLineDto> Lines { get; set; } = Array.Empty<InvoiceLineDto>();
}

public class CreateInvoiceLineRequest
{
    public int? ShipmentId { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
}

public class CreateInvoiceRequest
{
    public string InvoiceNo { get; set; } = string.Empty;
    public int CustomerId { get; set; }
    public DateOnly InvoiceDate { get; set; }
    public DateOnly DueDate { get; set; }
    public decimal TaxAmount { get; set; }
    public int StatusId { get; set; }
    public List<CreateInvoiceLineRequest> Lines { get; set; } = new();
}

public class InvoiceSummaryDto
{
    public int InvoiceCount { get; set; }
    public decimal TotalInvoiced { get; set; }
    public decimal TotalPaid { get; set; }
    public decimal TotalOutstanding { get; set; }
}
