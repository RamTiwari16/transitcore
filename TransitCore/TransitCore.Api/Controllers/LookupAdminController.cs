using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;

namespace TransitCore.Api.Controllers;

[Authorize(Roles = "Admin")]
[Route("api/v1/lookup-admin")]
[ApiController]
public class LookupAdminController : ControllerBase
{
    private readonly ILookupAdminService _lookupAdminService;

    public LookupAdminController(ILookupAdminService lookupAdminService)
    {
        _lookupAdminService = lookupAdminService;
    }

    // ---- Reads with no existing endpoint ----

    [HttpGet("countries")]
    public async Task<IActionResult> GetCountries(CancellationToken cancellationToken)
    {
        var countries = await _lookupAdminService.GetCountriesAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<CountryDto>>.Ok(countries));
    }

    [HttpGet("status-codes")]
    public async Task<IActionResult> GetAllStatusCodes(CancellationToken cancellationToken)
    {
        var statusCodes = await _lookupAdminService.GetAllStatusCodesAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<StatusCodeDto>>.Ok(statusCodes));
    }

    // ---- Regions ----

    [HttpPost("regions")]
    public async Task<IActionResult> CreateRegion([FromBody] CreateRegionRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _lookupAdminService.CreateRegionAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Region added successfully"));
    }

    [HttpPut("regions")]
    public async Task<IActionResult> UpdateRegion([FromBody] UpdateRegionRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _lookupAdminService.UpdateRegionAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Region not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Region updated successfully"));
    }

    [HttpDelete("regions/{id:int}")]
    public async Task<IActionResult> DeleteRegion(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _lookupAdminService.DeleteRegionAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Region not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Region removed"));
    }

    // ---- Branches ----

    [HttpPost("branches")]
    public async Task<IActionResult> CreateBranch([FromBody] CreateBranchRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _lookupAdminService.CreateBranchAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Branch added successfully"));
    }

    [HttpPut("branches")]
    public async Task<IActionResult> UpdateBranch([FromBody] UpdateBranchRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _lookupAdminService.UpdateBranchAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Branch not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Branch updated successfully"));
    }

    [HttpDelete("branches/{id:int}")]
    public async Task<IActionResult> DeleteBranch(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _lookupAdminService.DeleteBranchAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Branch not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Branch removed"));
    }

    // ---- Designations ----

    [HttpPost("designations")]
    public async Task<IActionResult> CreateDesignation([FromBody] CreateDesignationRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _lookupAdminService.CreateDesignationAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Designation added successfully"));
    }

    [HttpPut("designations")]
    public async Task<IActionResult> UpdateDesignation([FromBody] UpdateDesignationRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _lookupAdminService.UpdateDesignationAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Designation not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Designation updated successfully"));
    }

    [HttpDelete("designations/{id:int}")]
    public async Task<IActionResult> DeleteDesignation(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _lookupAdminService.DeleteDesignationAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Designation not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Designation removed"));
    }

    // ---- WorkingDesignations ----

    [HttpPost("working-designations")]
    public async Task<IActionResult> CreateWorkingDesignation([FromBody] CreateWorkingDesignationRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _lookupAdminService.CreateWorkingDesignationAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Working designation added successfully"));
    }

    [HttpPut("working-designations")]
    public async Task<IActionResult> UpdateWorkingDesignation([FromBody] UpdateWorkingDesignationRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _lookupAdminService.UpdateWorkingDesignationAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Working designation not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Working designation updated successfully"));
    }

    [HttpDelete("working-designations/{id:int}")]
    public async Task<IActionResult> DeleteWorkingDesignation(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _lookupAdminService.DeleteWorkingDesignationAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Working designation not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Working designation removed"));
    }

    // ---- Countries ----

    [HttpPost("countries")]
    public async Task<IActionResult> CreateCountry([FromBody] CreateCountryRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _lookupAdminService.CreateCountryAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Country added successfully"));
    }

    [HttpPut("countries")]
    public async Task<IActionResult> UpdateCountry([FromBody] UpdateCountryRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _lookupAdminService.UpdateCountryAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Country not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Country updated successfully"));
    }

    [HttpDelete("countries/{id:int}")]
    public async Task<IActionResult> DeleteCountry(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _lookupAdminService.DeleteCountryAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Country not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Country removed"));
    }

    // ---- Cities ----

    [HttpPost("cities")]
    public async Task<IActionResult> CreateCity([FromBody] CreateCityRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _lookupAdminService.CreateCityAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "City added successfully"));
    }

    [HttpPut("cities")]
    public async Task<IActionResult> UpdateCity([FromBody] UpdateCityRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _lookupAdminService.UpdateCityAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("City not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "City updated successfully"));
    }

    [HttpDelete("cities/{id:int}")]
    public async Task<IActionResult> DeleteCity(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _lookupAdminService.DeleteCityAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("City not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "City removed"));
    }

    // ---- StatusCodes ----

    [HttpPost("status-codes")]
    public async Task<IActionResult> CreateStatusCode([FromBody] CreateStatusCodeRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _lookupAdminService.CreateStatusCodeAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Status code added successfully"));
    }

    [HttpPut("status-codes")]
    public async Task<IActionResult> UpdateStatusCode([FromBody] UpdateStatusCodeRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _lookupAdminService.UpdateStatusCodeAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Status code not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Status code updated successfully"));
    }

    [HttpDelete("status-codes/{id:int}")]
    public async Task<IActionResult> DeleteStatusCode(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _lookupAdminService.DeleteStatusCodeAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Status code not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Status code removed"));
    }

    // ---- UnitsOfMeasure ----

    [HttpPost("units-of-measure")]
    public async Task<IActionResult> CreateUnitOfMeasure([FromBody] CreateUnitOfMeasureRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _lookupAdminService.CreateUnitOfMeasureAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Unit of measure added successfully"));
    }

    [HttpPut("units-of-measure")]
    public async Task<IActionResult> UpdateUnitOfMeasure([FromBody] UpdateUnitOfMeasureRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _lookupAdminService.UpdateUnitOfMeasureAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Unit of measure not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Unit of measure updated successfully"));
    }

    [HttpDelete("units-of-measure/{id:int}")]
    public async Task<IActionResult> DeleteUnitOfMeasure(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _lookupAdminService.DeleteUnitOfMeasureAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Unit of measure not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Unit of measure removed"));
    }

    // ---- Required compliance document types (F8) ----

    [HttpGet("required-compliance-document-types")]
    public async Task<IActionResult> GetRequiredComplianceDocumentTypes(CancellationToken cancellationToken)
    {
        var types = await _lookupAdminService.GetRequiredComplianceDocumentTypesAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<RequiredComplianceDocumentTypeDto>>.Ok(types));
    }

    [HttpPost("required-compliance-document-types")]
    public async Task<IActionResult> CreateRequiredComplianceDocumentType([FromBody] CreateRequiredComplianceDocumentTypeRequest request, CancellationToken cancellationToken)
    {
        var createdBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var newId = await _lookupAdminService.CreateRequiredComplianceDocumentTypeAsync(request, createdBy, cancellationToken);
        return Ok(ApiResponse<int>.Ok(newId, "Required document type added successfully"));
    }

    [HttpPut("required-compliance-document-types")]
    public async Task<IActionResult> UpdateRequiredComplianceDocumentType([FromBody] UpdateRequiredComplianceDocumentTypeRequest request, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var updated = await _lookupAdminService.UpdateRequiredComplianceDocumentTypeAsync(request, modifiedBy, cancellationToken);

        if (!updated)
            return NotFound(ApiResponse<string>.Fail("Required document type not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Required document type updated successfully"));
    }

    [HttpDelete("required-compliance-document-types/{id:int}")]
    public async Task<IActionResult> DeleteRequiredComplianceDocumentType(int id, CancellationToken cancellationToken)
    {
        var modifiedBy = User.FindFirst(ClaimTypes.Email)?.Value ?? "unknown";
        var deleted = await _lookupAdminService.DeleteRequiredComplianceDocumentTypeAsync(id, modifiedBy, cancellationToken);

        if (!deleted)
            return NotFound(ApiResponse<string>.Fail("Required document type not found"));

        return Ok(ApiResponse<string>.Ok(string.Empty, "Required document type removed"));
    }
}
