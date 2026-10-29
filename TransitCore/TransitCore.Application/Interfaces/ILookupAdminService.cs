using TransitCore.Application.Models;

namespace TransitCore.Application.Interfaces;

public interface ILookupAdminService
{
    Task<IReadOnlyList<CountryDto>> GetCountriesAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<StatusCodeDto>> GetAllStatusCodesAsync(CancellationToken cancellationToken = default);

    Task<int> CreateRegionAsync(CreateRegionRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateRegionAsync(UpdateRegionRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteRegionAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<int> CreateBranchAsync(CreateBranchRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateBranchAsync(UpdateBranchRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteBranchAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<int> CreateDesignationAsync(CreateDesignationRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateDesignationAsync(UpdateDesignationRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteDesignationAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<int> CreateWorkingDesignationAsync(CreateWorkingDesignationRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateWorkingDesignationAsync(UpdateWorkingDesignationRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteWorkingDesignationAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<int> CreateCountryAsync(CreateCountryRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateCountryAsync(UpdateCountryRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteCountryAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<int> CreateCityAsync(CreateCityRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateCityAsync(UpdateCityRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteCityAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<int> CreateStatusCodeAsync(CreateStatusCodeRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateStatusCodeAsync(UpdateStatusCodeRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteStatusCodeAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<int> CreateUnitOfMeasureAsync(CreateUnitOfMeasureRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateUnitOfMeasureAsync(UpdateUnitOfMeasureRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteUnitOfMeasureAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<RequiredComplianceDocumentTypeDto>> GetRequiredComplianceDocumentTypesAsync(CancellationToken cancellationToken = default);
    Task<int> CreateRequiredComplianceDocumentTypeAsync(CreateRequiredComplianceDocumentTypeRequest request, string createdBy, CancellationToken cancellationToken = default);
    Task<bool> UpdateRequiredComplianceDocumentTypeAsync(UpdateRequiredComplianceDocumentTypeRequest request, string modifiedBy, CancellationToken cancellationToken = default);
    Task<bool> DeleteRequiredComplianceDocumentTypeAsync(int id, string modifiedBy, CancellationToken cancellationToken = default);
}
