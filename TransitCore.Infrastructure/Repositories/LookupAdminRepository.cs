using System.Data;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class LookupAdminRepository : ILookupAdminService
{
    private readonly SqlDataAccess _db;

    public LookupAdminRepository(SqlDataAccess db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<CountryDto>> GetCountriesAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("lookup.usp_GetCountries", cancellationToken: cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new CountryDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Code = row["Code"].ToString() ?? string.Empty,
                Name = row["Name"].ToString() ?? string.Empty
            })
            .ToList();
    }

    public async Task<IReadOnlyList<StatusCodeDto>> GetAllStatusCodesAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("lookup.usp_GetAllStatusCodes", cancellationToken: cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new StatusCodeDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Category = row["Category"].ToString() ?? string.Empty,
                Code = row["Code"].ToString() ?? string.Empty,
                Name = row["Name"].ToString() ?? string.Empty,
                SortOrder = Convert.ToInt32(row["SortOrder"])
            })
            .ToList();
    }

    // ---- Regions ----

    public async Task<int> CreateRegionAsync(CreateRegionRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("lookup.usp_InsertRegion", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateRegionAsync(UpdateRegionRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", request.Id),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_UpdateRegion", parameters, cancellationToken);
        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<bool> DeleteRegionAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_DeleteRegion", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Branches ----

    public async Task<int> CreateBranchAsync(CreateBranchRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@RegionId", request.RegionId),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("lookup.usp_InsertBranch", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateBranchAsync(UpdateBranchRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", request.Id),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@RegionId", request.RegionId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_UpdateBranch", parameters, cancellationToken);
        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<bool> DeleteBranchAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_DeleteBranch", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Designations ----

    public async Task<int> CreateDesignationAsync(CreateDesignationRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("lookup.usp_InsertDesignation", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateDesignationAsync(UpdateDesignationRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", request.Id),
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_UpdateDesignation", parameters, cancellationToken);
        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<bool> DeleteDesignationAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_DeleteDesignation", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- WorkingDesignations ----

    public async Task<int> CreateWorkingDesignationAsync(CreateWorkingDesignationRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("lookup.usp_InsertWorkingDesignation", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateWorkingDesignationAsync(UpdateWorkingDesignationRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", request.Id),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_UpdateWorkingDesignation", parameters, cancellationToken);
        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<bool> DeleteWorkingDesignationAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_DeleteWorkingDesignation", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Countries ----

    public async Task<int> CreateCountryAsync(CreateCountryRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("lookup.usp_InsertCountry", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateCountryAsync(UpdateCountryRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", request.Id),
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_UpdateCountry", parameters, cancellationToken);
        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<bool> DeleteCountryAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_DeleteCountry", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Cities ----

    public async Task<int> CreateCityAsync(CreateCityRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@CountryId", request.CountryId),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("lookup.usp_InsertCity", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateCityAsync(UpdateCityRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", request.Id),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@CountryId", request.CountryId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_UpdateCity", parameters, cancellationToken);
        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<bool> DeleteCityAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_DeleteCity", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- StatusCodes ----

    public async Task<int> CreateStatusCodeAsync(CreateStatusCodeRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Category", request.Category),
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@SortOrder", request.SortOrder),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("lookup.usp_InsertStatusCode", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateStatusCodeAsync(UpdateStatusCodeRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", request.Id),
            new SqlParameter("@Category", request.Category),
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@SortOrder", request.SortOrder),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_UpdateStatusCode", parameters, cancellationToken);
        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<bool> DeleteStatusCodeAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_DeleteStatusCode", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- UnitsOfMeasure ----

    public async Task<int> CreateUnitOfMeasureAsync(CreateUnitOfMeasureRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("lookup.usp_InsertUnitOfMeasure", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateUnitOfMeasureAsync(UpdateUnitOfMeasureRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", request.Id),
            new SqlParameter("@Code", request.Code),
            new SqlParameter("@Name", request.Name),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_UpdateUnitOfMeasure", parameters, cancellationToken);
        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<bool> DeleteUnitOfMeasureAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("lookup.usp_DeleteUnitOfMeasure", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<IReadOnlyList<RequiredComplianceDocumentTypeDto>> GetRequiredComplianceDocumentTypesAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("fleet.usp_GetRequiredComplianceDocumentTypes", cancellationToken: cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new RequiredComplianceDocumentTypeDto
            {
                Id = Convert.ToInt32(row["Id"]),
                DocumentType = row["DocumentType"].ToString() ?? string.Empty,
                IsActive = Convert.ToBoolean(row["IsActive"])
            })
            .ToList();
    }

    public async Task<int> CreateRequiredComplianceDocumentTypeAsync(CreateRequiredComplianceDocumentTypeRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@DocumentType", request.DocumentType),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("fleet.usp_InsertRequiredComplianceDocumentType", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateRequiredComplianceDocumentTypeAsync(UpdateRequiredComplianceDocumentTypeRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@Id", request.Id),
            new SqlParameter("@DocumentType", request.DocumentType),
            new SqlParameter("@IsActive", request.IsActive),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("fleet.usp_UpdateRequiredComplianceDocumentType", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<bool> DeleteRequiredComplianceDocumentTypeAsync(int id, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@Id", id),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("fleet.usp_DeleteRequiredComplianceDocumentType", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }
}
