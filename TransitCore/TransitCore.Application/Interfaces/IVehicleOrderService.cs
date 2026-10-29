using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface IVehicleOrderService
{
    Task<int> BulkInsertAsync(IReadOnlyList<VehicleOrderMappingRow> rows, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<VehicleOrderMappingDto>> GetByDateRangeAsync(DateOnly fromDate, DateOnly toDate, CancellationToken cancellationToken = default);
}
