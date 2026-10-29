namespace TransitCore.Application.Models;

public class VendorDto
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? ContactName { get; set; }
    public string? ContactPhone { get; set; }
    public string? ContactEmail { get; set; }
    public string? Address { get; set; }
    public string? BankAccountNo { get; set; }
    public string? BankIfscCode { get; set; }
    public string? PanNo { get; set; }
    public string? GstinNo { get; set; }
    public bool IsActive { get; set; }
}

public class CreateVendorRequest
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string? ContactName { get; set; }
    public string? ContactPhone { get; set; }
    public string? ContactEmail { get; set; }
    public string? Address { get; set; }
    public string? BankAccountNo { get; set; }
    public string? BankIfscCode { get; set; }
    public string? PanNo { get; set; }
    public string? GstinNo { get; set; }
}

public class UpdateVendorRequest
{
    public int VendorId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? ContactName { get; set; }
    public string? ContactPhone { get; set; }
    public string? ContactEmail { get; set; }
    public string? Address { get; set; }
    public string? BankAccountNo { get; set; }
    public string? BankIfscCode { get; set; }
    public string? PanNo { get; set; }
    public string? GstinNo { get; set; }
    public bool IsActive { get; set; }
}

// ---- Vendor cost ledger (informational - see schema file's design note on
// why advances/deductions aren't auto-reconciled into VendorBills) ----

public class VendorAdvanceDto
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public int VendorId { get; set; }
    public decimal Amount { get; set; }
    public DateOnly AdvanceDate { get; set; }
    public string? Remarks { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
}

public class CreateVendorAdvanceRequest
{
    public int TripId { get; set; }
    public int VendorId { get; set; }
    public decimal Amount { get; set; }
    public DateOnly AdvanceDate { get; set; }
    public string? Remarks { get; set; }
}

public class VendorDeductionDto
{
    public int Id { get; set; }
    public int TripId { get; set; }
    public int VendorId { get; set; }
    public decimal Amount { get; set; }
    public string Reason { get; set; } = string.Empty;
    public DateOnly DeductionDate { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
}

public class CreateVendorDeductionRequest
{
    public int TripId { get; set; }
    public int VendorId { get; set; }
    public decimal Amount { get; set; }
    public string Reason { get; set; } = string.Empty;
    public DateOnly DeductionDate { get; set; }
}

// ---- Vendor bills / payments (formal billing, mirrors Invoice/Payment) ----

public class VendorBillDto
{
    public int Id { get; set; }
    public int VendorId { get; set; }
    public string VendorName { get; set; } = string.Empty;
    public int TripId { get; set; }
    public string BillNo { get; set; } = string.Empty;
    public DateOnly BillDate { get; set; }
    public DateOnly DueDate { get; set; }
    public decimal Amount { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public decimal PaidAmount { get; set; }
}

public class VendorPaymentDto
{
    public int Id { get; set; }
    public DateOnly PaymentDate { get; set; }
    public decimal Amount { get; set; }
    public string Method { get; set; } = string.Empty;
    public string? ReferenceNo { get; set; }
}

public class VendorBillDetailDto : VendorBillDto
{
    public IReadOnlyList<VendorPaymentDto> Payments { get; set; } = Array.Empty<VendorPaymentDto>();
}

public class CreateVendorBillRequest
{
    public int TripId { get; set; }
    public string BillNo { get; set; } = string.Empty;
    public DateOnly BillDate { get; set; }
    public DateOnly DueDate { get; set; }
    public int StatusId { get; set; }
}

public class CreateVendorPaymentRequest
{
    public int VendorBillId { get; set; }
    public DateOnly PaymentDate { get; set; }
    public decimal Amount { get; set; }
    public string Method { get; set; } = string.Empty;
    public string? ReferenceNo { get; set; }
}

public class VendorOutstandingBalanceDto
{
    public int VendorId { get; set; }
    public decimal OutstandingBalance { get; set; }
}

public class VendorAgingReportLineDto
{
    public int Id { get; set; }
    public string BillNo { get; set; } = string.Empty;
    public int VendorId { get; set; }
    public string VendorName { get; set; } = string.Empty;
    public DateOnly BillDate { get; set; }
    public DateOnly DueDate { get; set; }
    public decimal OutstandingAmount { get; set; }
    public int DaysOverdue { get; set; }
}
