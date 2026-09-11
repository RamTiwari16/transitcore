using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IBillingService
{
    Task<IReadOnlyList<CustomerDto>> GetCustomersAsync(bool activeOnly, CancellationToken cancellationToken = default);
    Task<int> CreateCustomerAsync(CreateCustomerRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<InvoiceDto>> GetInvoicesAsync(InvoiceFilterRequest filter, CancellationToken cancellationToken = default);
    Task<InvoiceDetailDto?> GetInvoiceByIdAsync(int invoiceId, CancellationToken cancellationToken = default);
    Task<int> CreateInvoiceAsync(CreateInvoiceRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<InvoiceSummaryDto> GetInvoiceSummaryAsync(DateOnly fromDate, DateOnly toDate, int? customerId, CancellationToken cancellationToken = default);
}
