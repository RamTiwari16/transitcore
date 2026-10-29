using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IOpsService
{
    Task<IReadOnlyList<RouteDto>> GetRoutesAsync(CancellationToken cancellationToken = default);
    Task<RouteDto?> GetRouteByIdAsync(int routeId, CancellationToken cancellationToken = default);
    Task<int> CreateRouteAsync(CreateRouteRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateRouteAsync(UpdateRouteRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<PagedResult<TripDto>> GetTripsAsync(TripFilterRequest filter, int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<TripDetailDto?> GetTripByIdAsync(int tripId, CancellationToken cancellationToken = default);
    Task<int> CreateTripAsync(CreateTripRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task UpdateTripStatusAsync(UpdateTripStatusRequest request, string changedBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateTripAsync(UpdateTripRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ShipmentDto>> GetShipmentsAsync(ShipmentFilterRequest filter, CancellationToken cancellationToken = default);
    Task<ShipmentDetailDto?> GetShipmentByIdAsync(int shipmentId, CancellationToken cancellationToken = default);
    // branchId/financialYearCode are resolved by the controller (current
    // user's primary branch; FinancialYearCalculator on the shipment date)
    // rather than accepted from the client - see SetPrimaryBranchRequest's
    // comment.
    Task<int> CreateShipmentAsync(CreateShipmentRequest request, string createdBy, int branchId, string financialYearCode, CancellationToken cancellationToken = default);
    Task<bool> UpdateShipmentAsync(UpdateShipmentRequest request, string modifiedBy, CancellationToken cancellationToken = default);

    Task<ConsignmentNoteDetailDto?> GetConsignmentNoteByShipmentIdAsync(int shipmentId, CancellationToken cancellationToken = default);
    Task<bool> CancelConsignmentNoteAsync(CancelConsignmentNoteRequest request, string cancelledBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TripExpenseDto>> GetTripExpensesAsync(int tripId, CancellationToken cancellationToken = default);
    Task<int> CreateTripExpenseAsync(CreateTripExpenseRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteTripExpenseAsync(int expenseId, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TripAdvanceDto>> GetTripAdvancesAsync(int tripId, CancellationToken cancellationToken = default);
    Task<int> CreateTripAdvanceAsync(CreateTripAdvanceRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteTripAdvanceAsync(int advanceId, string modifiedBy, CancellationToken cancellationToken = default);

    Task<TripCostSummaryDto> GetTripCostSummaryAsync(int tripId, CancellationToken cancellationToken = default);

    Task<ProofOfDeliveryDto?> GetProofOfDeliveryAsync(int tripId, CancellationToken cancellationToken = default);
    Task<int> CreateProofOfDeliveryAsync(CreateProofOfDeliveryRequest request, string createdBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TripDocumentDto>> GetTripDocumentsAsync(int tripId, CancellationToken cancellationToken = default);
    Task<int> CreateTripDocumentAsync(int tripId, string documentType, string fileName, string filePath, string uploadedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteTripDocumentAsync(int documentId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TripIncidentDto>> GetTripIncidentsAsync(int tripId, CancellationToken cancellationToken = default);
    Task<int> CreateTripIncidentAsync(CreateTripIncidentRequest request, string reportedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteTripIncidentAsync(int incidentId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RouteStopDto>> GetRouteStopsAsync(int routeId, CancellationToken cancellationToken = default);
    Task<int> CreateRouteStopAsync(CreateRouteStopRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteRouteStopAsync(int stopId, string modifiedBy, CancellationToken cancellationToken = default);

    Task<TripCapacityCheckDto> GetTripCapacityCheckAsync(int tripId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<TripConflictDto>> CheckTripConflictsAsync(CheckTripConflictsRequest request, CancellationToken cancellationToken = default);

    Task<ShipmentTrackingDto?> TrackShipmentAsync(string trackingNo, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TripStopShipmentDto>> GetTripStopShipmentsAsync(int tripId, CancellationToken cancellationToken = default);
    Task<(bool Success, string? ErrorMessage)> CreateTripStopShipmentAsync(CreateTripStopShipmentRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteTripStopShipmentAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TripStopVisitDto>> GetTripStopVisitsAsync(int tripId, CancellationToken cancellationToken = default);
    Task<TripStopVisitDto> UpsertTripStopVisitAsync(UpsertTripStopVisitRequest request, string createdBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<VendorAdvanceDto>> GetVendorAdvancesAsync(int tripId, CancellationToken cancellationToken = default);
    Task<int> CreateVendorAdvanceAsync(CreateVendorAdvanceRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteVendorAdvanceAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<VendorDeductionDto>> GetVendorDeductionsAsync(int tripId, CancellationToken cancellationToken = default);
    Task<int> CreateVendorDeductionAsync(CreateVendorDeductionRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteVendorDeductionAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<bool> UpdateTripKmAsync(UpdateTripKmRequest request, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ShipmentItemDeliveryLineDto>> GetShipmentItemDeliveriesAsync(int shipmentId, CancellationToken cancellationToken = default);
    Task<int> CreateShipmentItemDeliveryAsync(CreateShipmentItemDeliveryRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateShipmentItemDeliveryAsync(UpdateShipmentItemDeliveryRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<int> AddShipmentItemDeliveryPhotoAsync(int deliveryId, string filePath, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TripDispatchComplianceCheckDto>> CheckTripDispatchComplianceAsync(int tripId, CancellationToken cancellationToken = default);

    Task<bool> UpdateConsignmentNoteEwayBillAsync(UpdateConsignmentNoteEwayBillRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ExpiringEwayBillDto>> GetExpiringEwayBillsAsync(int daysAhead, CancellationToken cancellationToken = default);
}
