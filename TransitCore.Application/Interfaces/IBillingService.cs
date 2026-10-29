using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IBillingService
{
    Task<IReadOnlyList<CustomerDto>> GetCustomersAsync(bool activeOnly, CancellationToken cancellationToken = default);
    Task<CustomerDto?> GetCustomerByIdAsync(int customerId, CancellationToken cancellationToken = default);
    Task<int> CreateCustomerAsync(CreateCustomerRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateCustomerAsync(UpdateCustomerRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<InvoiceDto>> GetInvoicesAsync(InvoiceFilterRequest filter, CancellationToken cancellationToken = default);
    Task<InvoiceDetailDto?> GetInvoiceByIdAsync(int invoiceId, CancellationToken cancellationToken = default);
    Task<int> CreateInvoiceAsync(CreateInvoiceRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<InvoiceSummaryDto> GetInvoiceSummaryAsync(DateOnly fromDate, DateOnly toDate, int? customerId, CancellationToken cancellationToken = default);
    Task<CustomerOutstandingBalanceDto> GetCustomerOutstandingBalanceAsync(int customerId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RateCardDto>> GetRateCardsAsync(int? customerId, CancellationToken cancellationToken = default);
    Task<int> CreateRateCardAsync(CreateRateCardRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteRateCardAsync(int rateCardId, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<UninvoicedShipmentDto>> GetUninvoicedShipmentsAsync(int customerId, DateOnly fromDate, DateOnly toDate, CancellationToken cancellationToken = default);

    Task<int> CreatePaymentAsync(CreatePaymentRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeletePaymentAsync(int paymentId, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<AgingReportLineDto>> GetAgingReportAsync(DateOnly? asOfDate, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RateCardDto>> GetApplicableRateCardsAsync(int customerId, int originCityId, int destinationCityId, DateOnly asOfDate, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ShipmentChargeDto>> GetShipmentChargesAsync(int shipmentId, CancellationToken cancellationToken = default);
    Task<(bool Success, string? ErrorMessage, int? NewId)> CreateShipmentChargeAsync(CreateShipmentChargeRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteShipmentChargeAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<(bool Success, string? ErrorMessage, int? NewInvoiceId)> CreateInvoiceFromChargesAsync(GenerateInvoiceFromChargesRequest request, string createdBy, CancellationToken cancellationToken = default);

    // ---- Vendors (F5) ----
    Task<IReadOnlyList<VendorDto>> GetVendorsAsync(bool activeOnly, CancellationToken cancellationToken = default);
    Task<VendorDto?> GetVendorByIdAsync(int vendorId, CancellationToken cancellationToken = default);
    Task<int> CreateVendorAsync(CreateVendorRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateVendorAsync(UpdateVendorRequest request, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<VendorBillDto>> GetVendorBillsAsync(int? vendorId, int? statusId, CancellationToken cancellationToken = default);
    Task<VendorBillDetailDto?> GetVendorBillByIdAsync(int vendorBillId, CancellationToken cancellationToken = default);
    Task<(bool Success, string? ErrorMessage, int? NewId, decimal? Amount)> CreateVendorBillAsync(CreateVendorBillRequest request, string createdBy, CancellationToken cancellationToken = default);

    Task<int> CreateVendorPaymentAsync(CreateVendorPaymentRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteVendorPaymentAsync(int paymentId, string modifiedBy, CancellationToken cancellationToken = default);

    Task<VendorOutstandingBalanceDto> GetVendorOutstandingBalanceAsync(int vendorId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<VendorAgingReportLineDto>> GetVendorAgingReportAsync(DateOnly? asOfDate, CancellationToken cancellationToken = default);

    // ---- Claims (F7) ----
    Task<PagedResult<ClaimDto>> GetClaimsAsync(ClaimFilterRequest filter, int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<ClaimDetailDto?> GetClaimByIdAsync(int claimId, CancellationToken cancellationToken = default);
    Task<int> CreateClaimAsync(CreateClaimRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<(bool Success, string? ErrorMessage)> UpdateClaimAsync(UpdateClaimRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<(bool Success, string? ErrorMessage)> UpdateClaimStatusAsync(UpdateClaimStatusRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<(bool Success, string? ErrorMessage)> SettleClaimAsync(SettleClaimRequest request, string modifiedBy, CancellationToken cancellationToken = default);
}
