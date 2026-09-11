using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;

namespace TransitCore.Api.Controllers;

[Authorize]
[Route("api/v1/[controller]")]
[ApiController]
public class LookupController : ControllerBase
{
    private readonly ILookupService _lookupService;

    public LookupController(ILookupService lookupService)
    {
        _lookupService = lookupService;
    }

    [HttpGet("cities")]
    public async Task<IActionResult> GetCities(CancellationToken cancellationToken)
    {
        var cities = await _lookupService.GetCitiesAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<CityDto>>.Ok(cities));
    }

    [HttpGet("regions")]
    public async Task<IActionResult> GetRegions(CancellationToken cancellationToken)
    {
        var regions = await _lookupService.GetRegionsAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<RegionDto>>.Ok(regions));
    }

    [HttpGet("branches")]
    public async Task<IActionResult> GetBranches([FromQuery] int? regionId, CancellationToken cancellationToken)
    {
        var branches = await _lookupService.GetBranchesAsync(regionId, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<BranchDto>>.Ok(branches));
    }

    [HttpGet("designations")]
    public async Task<IActionResult> GetDesignations(CancellationToken cancellationToken)
    {
        var designations = await _lookupService.GetDesignationsAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<DesignationDto>>.Ok(designations));
    }

    [HttpGet("working-designations")]
    public async Task<IActionResult> GetWorkingDesignations(CancellationToken cancellationToken)
    {
        var workingDesignations = await _lookupService.GetWorkingDesignationsAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<WorkingDesignationDto>>.Ok(workingDesignations));
    }

    [HttpGet("units-of-measure")]
    public async Task<IActionResult> GetUnitsOfMeasure(CancellationToken cancellationToken)
    {
        var units = await _lookupService.GetUnitsOfMeasureAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<UnitOfMeasureDto>>.Ok(units));
    }

    [HttpGet("status-codes")]
    public async Task<IActionResult> GetStatusCodes([FromQuery] string category, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(category))
            return BadRequest(ApiResponse<string>.Fail("category is required"));

        var statusCodes = await _lookupService.GetStatusCodesAsync(category, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<StatusCodeDto>>.Ok(statusCodes));
    }
}
