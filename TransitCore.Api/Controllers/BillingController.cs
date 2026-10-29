using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;

namespace TransitCore.Api.Controllers;

[Authorize]
[Route("api/v1/[controller]")]
[ApiController]
public class BillingController : ControllerBase
{
    private readonly IBillingService _billingService;
    private readonly IInvoicePdfGenerator _invoicePdfGenerator;

    public BillingController(IBillingService billingService, IInvoicePdfGenerator invoicePdfGenerator)
    {
        _billingService = billingService;
        _invoicePdfGenerator = invoicePdfGenerator;
    }

    [HttpGet("customers")]
    public async Task<IActionResult> GetCustomers([FromQuery] bool activeOnly, CancellationToken cancellationToken)
    {
        var customers = await _billingService.GetCustomersAsync(activeOnly, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<CustomerDto>>.Ok(customers));
    }

    [HttpGet("customers/{customerId:int}")]
    public async Task<IActionResult> GetCustomerById(int customerId, CancellationToken cancellationToken)
    {
        var customer = await _billingService.GetCustomerByIdAsync(customerId, cancellationToken);
        if (customer is null)
            return NotFound(ApiResponse<string>.Fail("Customer not found"));

        return Ok(ApiResponse<CustomerDto>.Ok(customer));
    }

    [HttpPost("customers")]
    public async Task<IActionResult> CreateCustomer([FromBody] CreateCustomerRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newCustomerId = await _billingService.CreateCustomerAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newCustomerId, "Customer created successfully"));
    }

    [HttpPut("customers")]
    public async Task<IActionResult> UpdateCustomer([FromBody] UpdateCustomerRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _billingService.UpdateCustomerAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Customer not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Customer updated successfully"));
    }

    [HttpGet("customers/{customerId:int}/outstanding-balance")]
    public async Task<IActionResult> GetCustomerOutstandingBalance(int customerId, CancellationToken cancellationToken)
    {
        var balance = await _billingService.GetCustomerOutstandingBalanceAsync(customerId, cancellationToken);
        return Ok(ApiResponse<CustomerOutstandingBalanceDto>.Ok(balance));
    }

    [HttpGet("customers/{customerId:int}/uninvoiced-shipments")]
    public async Task<IActionResult> GetUninvoicedShipments(int customerId, [FromQuery] DateOnly fromDate, [FromQuery] DateOnly toDate, CancellationToken cancellationToken)
    {
        if (fromDate > toDate)
            return BadRequest(ApiResponse<string>.Fail("fromDate cannot be greater than toDate"));

        var shipments = await _billingService.GetUninvoicedShipmentsAsync(customerId, fromDate, toDate, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<UninvoicedShipmentDto>>.Ok(shipments));
    }

    // ---- Rate cards ----

    [HttpGet("rate-cards")]
    public async Task<IActionResult> GetRateCards([FromQuery] int? customerId, CancellationToken cancellationToken)
    {
        var rateCards = await _billingService.GetRateCardsAsync(customerId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<RateCardDto>>.Ok(rateCards));
    }

    [HttpPost("rate-cards")]
    public async Task<IActionResult> CreateRateCard([FromBody] CreateRateCardRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _billingService.CreateRateCardAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Rate card added successfully"));
    }

    [HttpDelete("rate-cards/{rateCardId:int}")]
    public async Task<IActionResult> DeleteRateCard(int rateCardId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _billingService.DeleteRateCardAsync(rateCardId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Rate card not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Rate card removed"));
    }

    // ---- Shipment charges (F4) ----

    [HttpGet("shipments/{shipmentId:int}/charges")]
    public async Task<IActionResult> GetShipmentCharges(int shipmentId, CancellationToken cancellationToken)
    {
        var charges = await _billingService.GetShipmentChargesAsync(shipmentId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<ShipmentChargeDto>>.Ok(charges));
    }

    [HttpPost("shipments/{shipmentId:int}/charges")]
    public async Task<IActionResult> CreateShipmentCharge(int shipmentId, [FromBody] CreateShipmentChargeRequest request, CancellationToken cancellationToken)
    {
        request.ShipmentId = shipmentId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var (success, errorMessage, newId) = await _billingService.CreateShipmentChargeAsync(request, createdBy, cancellationToken);

        if (!success)
            return BadRequest(ApiResponse<string>.Fail(errorMessage ?? "Could not add this charge"));

        return Ok(ApiResponse<int>.Ok(newId!.Value, "Charge added successfully"));
    }

    [HttpDelete("shipment-charges/{id:int}")]
    public async Task<IActionResult> DeleteShipmentCharge(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _billingService.DeleteShipmentChargeAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Charge not found, or already invoiced"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Charge removed"));
    }

    [HttpGet("invoices")]
    public async Task<IActionResult> GetInvoices([FromQuery] InvoiceFilterRequest filter, CancellationToken cancellationToken)
    {
        var invoices = await _billingService.GetInvoicesAsync(filter, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<InvoiceDto>>.Ok(invoices));
    }

    [HttpGet("invoices/{invoiceId:int}")]
    public async Task<IActionResult> GetInvoiceById(int invoiceId, CancellationToken cancellationToken)
    {
        var invoice = await _billingService.GetInvoiceByIdAsync(invoiceId, cancellationToken);
        if (invoice is null)
            return NotFound(ApiResponse<string>.Fail("Invoice not found"));

        return Ok(ApiResponse<InvoiceDetailDto>.Ok(invoice));
    }

    [HttpGet("invoices/{invoiceId:int}/pdf")]
    public async Task<IActionResult> GetInvoicePdf(int invoiceId, CancellationToken cancellationToken)
    {
        var invoice = await _billingService.GetInvoiceByIdAsync(invoiceId, cancellationToken);
        if (invoice is null)
            return NotFound(ApiResponse<string>.Fail("Invoice not found"));

        var pdfBytes = _invoicePdfGenerator.Generate(invoice);
        return File(pdfBytes, "application/pdf", $"{invoice.InvoiceNo}.pdf");
    }

    [HttpPost("invoices")]
    public async Task<IActionResult> CreateInvoice([FromBody] CreateInvoiceRequest request, CancellationToken cancellationToken)
    {
        if (request.Lines.Count == 0)
            return BadRequest(ApiResponse<string>.Fail("At least one invoice line is required"));

        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newInvoiceId = await _billingService.CreateInvoiceAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newInvoiceId, "Invoice created successfully"));
    }

    // "Invoices build their lines from ShipmentCharges" (F4) - one invoice
    // line per selected charge, alongside (not replacing) the freeform
    // CreateInvoice path above.
    [HttpPost("invoices/from-charges")]
    public async Task<IActionResult> CreateInvoiceFromCharges([FromBody] GenerateInvoiceFromChargesRequest request, CancellationToken cancellationToken)
    {
        if (request.ShipmentChargeIds.Count == 0)
            return BadRequest(ApiResponse<string>.Fail("At least one charge is required"));

        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var (success, errorMessage, newInvoiceId) = await _billingService.CreateInvoiceFromChargesAsync(request, createdBy, cancellationToken);

        if (!success)
            return BadRequest(ApiResponse<string>.Fail(errorMessage ?? "Could not create the invoice"));

        return Ok(ApiResponse<int>.Ok(newInvoiceId!.Value, "Invoice created successfully"));
    }

    [HttpGet("invoices/summary")]
    public async Task<IActionResult> GetInvoiceSummary([FromQuery] DateOnly fromDate, [FromQuery] DateOnly toDate, [FromQuery] int? customerId, CancellationToken cancellationToken)
    {
        if (fromDate > toDate)
            return BadRequest(ApiResponse<string>.Fail("fromDate cannot be greater than toDate"));

        var summary = await _billingService.GetInvoiceSummaryAsync(fromDate, toDate, customerId, cancellationToken);
        return Ok(ApiResponse<InvoiceSummaryDto>.Ok(summary));
    }

    // ---- Payments / receipts ----

    [HttpPost("invoices/{invoiceId:int}/payments")]
    public async Task<IActionResult> CreatePayment(int invoiceId, [FromBody] CreatePaymentRequest request, CancellationToken cancellationToken)
    {
        request.InvoiceId = invoiceId;
        request.ShipmentId = null;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _billingService.CreatePaymentAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Payment recorded successfully"));
    }

    // F1's "ToPay" collection: the amount staff collect from the consignee
    // at delivery, recorded straight against the shipment (no invoice
    // exists for a ToPay shipment - see CK_Payments_OneTarget).
    [HttpPost("shipments/{shipmentId:int}/payments")]
    public async Task<IActionResult> CreateShipmentPayment(int shipmentId, [FromBody] CreatePaymentRequest request, CancellationToken cancellationToken)
    {
        request.ShipmentId = shipmentId;
        request.InvoiceId = null;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _billingService.CreatePaymentAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Payment recorded successfully"));
    }

    [HttpDelete("payments/{paymentId:int}")]
    public async Task<IActionResult> DeletePayment(int paymentId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _billingService.DeletePaymentAsync(paymentId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Payment not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Payment removed"));
    }

    // ---- AR aging ----

    [HttpGet("invoices/aging-report")]
    public async Task<IActionResult> GetAgingReport([FromQuery] DateOnly? asOfDate, CancellationToken cancellationToken)
    {
        var report = await _billingService.GetAgingReportAsync(asOfDate, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<AgingReportLineDto>>.Ok(report));
    }

    // ---- Vendors (F5) ----

    [HttpGet("vendors")]
    public async Task<IActionResult> GetVendors([FromQuery] bool activeOnly, CancellationToken cancellationToken)
    {
        var vendors = await _billingService.GetVendorsAsync(activeOnly, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VendorDto>>.Ok(vendors));
    }

    [HttpGet("vendors/{vendorId:int}")]
    public async Task<IActionResult> GetVendorById(int vendorId, CancellationToken cancellationToken)
    {
        var vendor = await _billingService.GetVendorByIdAsync(vendorId, cancellationToken);
        if (vendor is null)
            return NotFound(ApiResponse<string>.Fail("Vendor not found"));

        return Ok(ApiResponse<VendorDto>.Ok(vendor));
    }

    [HttpPost("vendors")]
    public async Task<IActionResult> CreateVendor([FromBody] CreateVendorRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _billingService.CreateVendorAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Vendor created successfully"));
    }

    [HttpPut("vendors")]
    public async Task<IActionResult> UpdateVendor([FromBody] UpdateVendorRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _billingService.UpdateVendorAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Vendor not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Vendor updated successfully"));
    }

    [HttpGet("vendors/{vendorId:int}/outstanding-balance")]
    public async Task<IActionResult> GetVendorOutstandingBalance(int vendorId, CancellationToken cancellationToken)
    {
        var balance = await _billingService.GetVendorOutstandingBalanceAsync(vendorId, cancellationToken);
        return Ok(ApiResponse<VendorOutstandingBalanceDto>.Ok(balance));
    }

    // ---- Vendor bills / payments (F5) ----

    [HttpGet("vendor-bills")]
    public async Task<IActionResult> GetVendorBills([FromQuery] int? vendorId, [FromQuery] int? statusId, CancellationToken cancellationToken)
    {
        var bills = await _billingService.GetVendorBillsAsync(vendorId, statusId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VendorBillDto>>.Ok(bills));
    }

    [HttpGet("vendor-bills/{vendorBillId:int}")]
    public async Task<IActionResult> GetVendorBillById(int vendorBillId, CancellationToken cancellationToken)
    {
        var bill = await _billingService.GetVendorBillByIdAsync(vendorBillId, cancellationToken);
        if (bill is null)
            return NotFound(ApiResponse<string>.Fail("Vendor bill not found"));

        return Ok(ApiResponse<VendorBillDetailDto>.Ok(bill));
    }

    [HttpPost("trips/{tripId:int}/vendor-bill")]
    public async Task<IActionResult> CreateVendorBill(int tripId, [FromBody] CreateVendorBillRequest request, CancellationToken cancellationToken)
    {
        request.TripId = tripId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var (success, errorMessage, newId, amount) = await _billingService.CreateVendorBillAsync(request, createdBy, cancellationToken);

        if (!success)
            return BadRequest(ApiResponse<string>.Fail(errorMessage ?? "Could not create the vendor bill"));

        return Ok(ApiResponse<int>.Ok(newId!.Value, $"Vendor bill created for {amount:N2}"));
    }

    [HttpPost("vendor-bills/{vendorBillId:int}/payments")]
    public async Task<IActionResult> CreateVendorPayment(int vendorBillId, [FromBody] CreateVendorPaymentRequest request, CancellationToken cancellationToken)
    {
        request.VendorBillId = vendorBillId;
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _billingService.CreateVendorPaymentAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Payment recorded successfully"));
    }

    [HttpDelete("vendor-payments/{paymentId:int}")]
    public async Task<IActionResult> DeleteVendorPayment(int paymentId, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _billingService.DeleteVendorPaymentAsync(paymentId, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Payment not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Payment removed"));
    }

    [HttpGet("vendor-bills/aging-report")]
    public async Task<IActionResult> GetVendorAgingReport([FromQuery] DateOnly? asOfDate, CancellationToken cancellationToken)
    {
        var report = await _billingService.GetVendorAgingReportAsync(asOfDate, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VendorAgingReportLineDto>>.Ok(report));
    }

    // ---- Claims (F7) ----

    [HttpGet("claims")]
    public async Task<IActionResult> GetClaims(
        [FromQuery] ClaimFilterRequest filter,
        [FromQuery] int pageNumber,
        [FromQuery] int pageSize,
        CancellationToken cancellationToken)
    {
        var claims = await _billingService.GetClaimsAsync(
            filter,
            pageNumber <= 0 ? 1 : pageNumber,
            pageSize <= 0 ? 25 : pageSize,
            cancellationToken);

        return Ok(ApiResponse<PagedResult<ClaimDto>>.Ok(claims));
    }

    [HttpGet("claims/{claimId:int}")]
    public async Task<IActionResult> GetClaimById(int claimId, CancellationToken cancellationToken)
    {
        var claim = await _billingService.GetClaimByIdAsync(claimId, cancellationToken);

        if (claim is null)
            return NotFound(ApiResponse<string>.Fail("Claim not found"));

        return Ok(ApiResponse<ClaimDetailDto>.Ok(claim));
    }

    [HttpPost("claims")]
    public async Task<IActionResult> CreateClaim([FromBody] CreateClaimRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _billingService.CreateClaimAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Claim raised"));
    }

    [HttpPut("claims/{claimId:int}")]
    public async Task<IActionResult> UpdateClaim(int claimId, [FromBody] UpdateClaimRequest request, CancellationToken cancellationToken)
    {
        request.ClaimId = claimId;
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var (success, errorMessage) = await _billingService.UpdateClaimAsync(request, modifiedBy, cancellationToken);

        if (!success)
            return BadRequest(ApiResponse<string>.Fail(errorMessage ?? "Unable to update claim"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Claim updated"));
    }

    [HttpPut("claims/{claimId:int}/status")]
    public async Task<IActionResult> UpdateClaimStatus(int claimId, [FromBody] UpdateClaimStatusRequest request, CancellationToken cancellationToken)
    {
        request.ClaimId = claimId;
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var (success, errorMessage) = await _billingService.UpdateClaimStatusAsync(request, modifiedBy, cancellationToken);

        if (!success)
            return BadRequest(ApiResponse<string>.Fail(errorMessage ?? "Unable to update claim status"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Claim status updated"));
    }

    [HttpPost("claims/{claimId:int}/settle")]
    public async Task<IActionResult> SettleClaim(int claimId, [FromBody] SettleClaimRequest request, CancellationToken cancellationToken)
    {
        request.ClaimId = claimId;
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var (success, errorMessage) = await _billingService.SettleClaimAsync(request, modifiedBy, cancellationToken);

        if (!success)
            return BadRequest(ApiResponse<string>.Fail(errorMessage ?? "Unable to settle claim"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Claim settled"));
    }
}
