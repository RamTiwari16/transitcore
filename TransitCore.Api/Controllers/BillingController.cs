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

    public BillingController(IBillingService billingService)
    {
        _billingService = billingService;
    }

    [HttpGet("customers")]
    public async Task<IActionResult> GetCustomers([FromQuery] bool activeOnly, CancellationToken cancellationToken)
    {
        var customers = await _billingService.GetCustomersAsync(activeOnly, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<CustomerDto>>.Ok(customers));
    }

    [HttpPost("customers")]
    public async Task<IActionResult> CreateCustomer([FromBody] CreateCustomerRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newCustomerId = await _billingService.CreateCustomerAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newCustomerId, "Customer created successfully"));
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

    [HttpPost("invoices")]
    public async Task<IActionResult> CreateInvoice([FromBody] CreateInvoiceRequest request, CancellationToken cancellationToken)
    {
        if (request.Lines.Count == 0)
            return BadRequest(ApiResponse<string>.Fail("At least one invoice line is required"));

        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newInvoiceId = await _billingService.CreateInvoiceAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newInvoiceId, "Invoice created successfully"));
    }

    [HttpGet("invoices/summary")]
    public async Task<IActionResult> GetInvoiceSummary([FromQuery] DateOnly fromDate, [FromQuery] DateOnly toDate, [FromQuery] int? customerId, CancellationToken cancellationToken)
    {
        if (fromDate > toDate)
            return BadRequest(ApiResponse<string>.Fail("fromDate cannot be greater than toDate"));

        var summary = await _billingService.GetInvoiceSummaryAsync(fromDate, toDate, customerId, cancellationToken);
        return Ok(ApiResponse<InvoiceSummaryDto>.Ok(summary));
    }
}
