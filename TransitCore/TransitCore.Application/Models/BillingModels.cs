namespace TransitCore.Application.Models;

public class CustomerDto
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public decimal? CreditLimit { get; set; }
}

public class CreateCustomerRequest
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public decimal? CreditLimit { get; set; }
}

// Code is the immutable natural key (see usp_UpdateCustomer's comment) - not
// accepted here at all, so there's no accidental way to change it.
public class UpdateCustomerRequest
{
    public int CustomerId { get; set; }
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public decimal? CreditLimit { get; set; }
}

public class CustomerOutstandingBalanceDto
{
    public int CustomerId { get; set; }
    public decimal OutstandingBalance { get; set; }
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
    public decimal DiscountAmount { get; set; }
    public decimal TaxAmount { get; set; }
    public decimal TotalAmount { get; set; }
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public decimal PaidAmount { get; set; }
    public decimal DeductionAmount { get; set; }
}

public class InvoiceLineDto
{
    public int Id { get; set; }
    public int? ShipmentId { get; set; }
    public int? ShipmentChargeId { get; set; }
    public string Description { get; set; } = string.Empty;
    public decimal Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal LineTotal { get; set; }
}

public class PaymentDto
{
    public int Id { get; set; }
    public DateOnly PaymentDate { get; set; }
    public decimal Amount { get; set; }
    public string Method { get; set; } = string.Empty;
    public string? ReferenceNo { get; set; }
}

public class InvoiceDetailDto : InvoiceDto
{
    public IReadOnlyList<InvoiceLineDto> Lines { get; set; } = Array.Empty<InvoiceLineDto>();
    public IReadOnlyList<PaymentDto> Payments { get; set; } = Array.Empty<PaymentDto>();
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
    public decimal DiscountAmount { get; set; }
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

// Exactly one of InvoiceId / ShipmentId is set - the controller action fills
// in whichever one its own route targets (POST invoices/{id}/payments vs
// POST shipments/{id}/payments), matching CK_Payments_OneTarget.
public class CreatePaymentRequest
{
    public int? InvoiceId { get; set; }
    public int? ShipmentId { get; set; }
    public DateOnly PaymentDate { get; set; }
    public decimal Amount { get; set; }
    public string Method { get; set; } = string.Empty;
    public string? ReferenceNo { get; set; }
}

public class AgingReportLineDto
{
    public int Id { get; set; }
    public string InvoiceNo { get; set; } = string.Empty;
    public int CustomerId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public DateOnly InvoiceDate { get; set; }
    public DateOnly DueDate { get; set; }
    public decimal OutstandingAmount { get; set; }
    public int DaysOverdue { get; set; }
}

// ---- Rate cards ----

public class RateCardDto
{
    public int Id { get; set; }
    public int? CustomerId { get; set; }
    public string? CustomerName { get; set; }
    public int? OriginCityId { get; set; }
    public string? OriginCityName { get; set; }
    public int? DestinationCityId { get; set; }
    public string? DestinationCityName { get; set; }
    public decimal RatePerKg { get; set; }
    public decimal RatePerKm { get; set; }
    // Basis picks which rate field below is actually used by
    // FreightCalculator - PerTrip/PerTon/PerKm/PerPackage. RatePerKm doubles
    // as the active rate for the PerKm basis; RatePerKg above is legacy,
    // never used by the calculator.
    public string Basis { get; set; } = string.Empty;
    public decimal? RatePerTrip { get; set; }
    public decimal? RatePerTon { get; set; }
    public decimal? RatePerPackage { get; set; }
    public decimal? MinimumChargeableWeightKg { get; set; }
    public decimal? LoadingRatePerEvent { get; set; }
    public decimal? UnloadingRatePerEvent { get; set; }
    public decimal? DetentionFreeHours { get; set; }
    public decimal? DetentionRatePerHour { get; set; }
    public decimal? HaltingRatePerDay { get; set; }
    public DateOnly EffectiveFrom { get; set; }
    public DateOnly? EffectiveTo { get; set; }
}

public class CreateRateCardRequest
{
    public int? CustomerId { get; set; }
    public int? OriginCityId { get; set; }
    public int? DestinationCityId { get; set; }
    public decimal RatePerKg { get; set; }
    public decimal RatePerKm { get; set; }
    public string Basis { get; set; } = "PerKm";
    public decimal? RatePerTrip { get; set; }
    public decimal? RatePerTon { get; set; }
    public decimal? RatePerPackage { get; set; }
    public decimal? MinimumChargeableWeightKg { get; set; }
    public decimal? LoadingRatePerEvent { get; set; }
    public decimal? UnloadingRatePerEvent { get; set; }
    public decimal? DetentionFreeHours { get; set; }
    public decimal? DetentionRatePerHour { get; set; }
    public decimal? HaltingRatePerDay { get; set; }
    public DateOnly EffectiveFrom { get; set; }
    public DateOnly? EffectiveTo { get; set; }
}

// ---- Generate invoice from shipments ----

public class UninvoicedShipmentDto
{
    public int Id { get; set; }
    public string? TrackingNo { get; set; }
    public int OriginCityId { get; set; }
    public string OriginCityName { get; set; } = string.Empty;
    public int DestinationCityId { get; set; }
    public string DestinationCityName { get; set; } = string.Empty;
    public DateOnly ShipmentDate { get; set; }
    public decimal TotalWeightKg { get; set; }
    public decimal? RouteDistanceKm { get; set; }
    public int? TotalPackages { get; set; }
    // Priced against the customer's best-matching rate card server-side
    // (see BillingService's rate-matching logic) - null when no rate card
    // covers this shipment at all, so the UI can flag it rather than
    // silently invoicing at 0.
    public decimal? EstimatedAmount { get; set; }
}

// ---- Shipment charges (F4) ----

public class ShipmentChargeDto
{
    public int Id { get; set; }
    public int ShipmentId { get; set; }
    public string ChargeType { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? Description { get; set; }
    public bool IsOverridden { get; set; }
    public string? OverrideReason { get; set; }
    public bool IsInvoiced { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
}

public class CreateShipmentChargeRequest
{
    public int ShipmentId { get; set; }
    public string ChargeType { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string? Description { get; set; }
    public bool IsOverridden { get; set; }
    public string? OverrideReason { get; set; }
}

public class GenerateInvoiceFromChargesRequest
{
    public string InvoiceNo { get; set; } = string.Empty;
    public int CustomerId { get; set; }
    public DateOnly InvoiceDate { get; set; }
    public DateOnly DueDate { get; set; }
    public decimal DiscountAmount { get; set; }
    public decimal TaxAmount { get; set; }
    public int StatusId { get; set; }
    public List<int> ShipmentChargeIds { get; set; } = new();
}
