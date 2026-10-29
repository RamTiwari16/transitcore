using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IFleetService
{
    Task<IReadOnlyList<VehicleTypeDto>> GetVehicleTypesAsync(CancellationToken cancellationToken = default);
    Task<PagedResult<VehicleDto>> GetVehiclesAsync(int? statusId, int? vehicleTypeId, int pageNumber, int pageSize, CancellationToken cancellationToken = default);
    Task<VehicleDto?> GetVehicleByIdAsync(int vehicleId, CancellationToken cancellationToken = default);
    Task<int> CreateVehicleAsync(CreateVehicleRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateVehicleAsync(UpdateVehicleRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<DriverDto>> GetDriversAsync(int? statusId, CancellationToken cancellationToken = default);
    Task<DriverDetailDto?> GetDriverByIdAsync(int driverId, CancellationToken cancellationToken = default);
    Task<int> CreateDriverAsync(CreateDriverRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateDriverAsync(UpdateDriverRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<FleetUtilisationDto>> GetFleetUtilisationAsync(DateOnly fromDate, DateOnly toDate, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<VehicleDocumentDto>> GetVehicleDocumentsAsync(int vehicleId, CancellationToken cancellationToken = default);
    Task<int> CreateVehicleDocumentAsync(CreateVehicleDocumentRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteVehicleDocumentAsync(int documentId, string modifiedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ExpiringVehicleDocumentDto>> GetExpiringVehicleDocumentsAsync(int daysAhead, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<MaintenanceRecordDto>> GetMaintenanceRecordsAsync(int vehicleId, CancellationToken cancellationToken = default);
    Task<int> CreateMaintenanceRecordAsync(CreateMaintenanceRecordRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteMaintenanceRecordAsync(int maintenanceId, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<FuelLogDto>> GetFuelLogsAsync(int vehicleId, CancellationToken cancellationToken = default);
    Task<int> CreateFuelLogAsync(CreateFuelLogRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteFuelLogAsync(int fuelLogId, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<DriverLicenseDto>> GetDriverLicensesAsync(int driverId, CancellationToken cancellationToken = default);
    Task<int> CreateDriverLicenseAsync(CreateDriverLicenseRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteDriverLicenseAsync(int licenseId, string modifiedBy, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<ExpiringDriverLicenseDto>> GetExpiringDriverLicensesAsync(int daysAhead, CancellationToken cancellationToken = default);

    Task<DriverPerformanceDto> GetDriverPerformanceAsync(int driverId, CancellationToken cancellationToken = default);

    Task<DriverSettlementDto> GetDriverSettlementAsync(int driverId, CancellationToken cancellationToken = default);
}
