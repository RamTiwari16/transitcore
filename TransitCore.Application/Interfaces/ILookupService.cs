using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface ILookupService
{
    Task<IReadOnlyList<CityDto>> GetCitiesAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<RegionDto>> GetRegionsAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<BranchDto>> GetBranchesAsync(int? regionId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<DesignationDto>> GetDesignationsAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<WorkingDesignationDto>> GetWorkingDesignationsAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StatusCodeDto>> GetStatusCodesAsync(string category, CancellationToken cancellationToken = default);
}
