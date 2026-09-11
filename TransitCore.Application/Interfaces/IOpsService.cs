using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IOpsService
{
    Task<IReadOnlyList<RouteDto>> GetRoutesAsync(CancellationToken cancellationToken = default);
    Task<PagedResult<TripDto>> GetTripsAsync(TripFilterRequest filter, int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<TripDetailDto?> GetTripByIdAsync(int tripId, CancellationToken cancellationToken = default);
    Task<int> CreateTripAsync(CreateTripRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task UpdateTripStatusAsync(UpdateTripStatusRequest request, string changedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ShipmentDto>> GetShipmentsAsync(ShipmentFilterRequest filter, CancellationToken cancellationToken = default);
    Task<ShipmentDetailDto?> GetShipmentByIdAsync(int shipmentId, CancellationToken cancellationToken = default);
    Task<int> CreateShipmentAsync(CreateShipmentRequest request, string createdBy, CancellationToken cancellationToken = default);
}
