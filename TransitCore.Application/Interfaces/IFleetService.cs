using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IFleetService
{
    Task<IReadOnlyList<VehicleTypeDto>> GetVehicleTypesAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<VehicleDto>> GetVehiclesAsync(int? statusId, int? vehicleTypeId, CancellationToken cancellationToken = default);
    Task<VehicleDto?> GetVehicleByIdAsync(int vehicleId, CancellationToken cancellationToken = default);
    Task<int> CreateVehicleAsync(CreateVehicleRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateVehicleAsync(UpdateVehicleRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<DriverDto>> GetDriversAsync(int? statusId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<FleetUtilisationDto>> GetFleetUtilisationAsync(DateOnly fromDate, DateOnly toDate, CancellationToken cancellationToken = default);
}
