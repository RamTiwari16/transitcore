using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;

namespace TransitCore.Api.Controllers;

// Deliberately its own controller, not [AllowAnonymous] actions bolted onto
// the authenticated OpsController - a separate controller makes the trust
// boundary obvious at a glance instead of relying on remembering which one
// attribute overrides the class-level [Authorize] elsewhere.
[AllowAnonymous]
[Route("api/v1/public")]
[ApiController]
public class PublicController : ControllerBase
{
    private readonly IOpsService _opsService;

    public PublicController(IOpsService opsService)
    {
        _opsService = opsService;
    }

    [HttpGet("track/{trackingNo}")]
    public async Task<IActionResult> TrackShipment(string trackingNo, CancellationToken cancellationToken)
    {
        var tracking = await _opsService.TrackShipmentAsync(trackingNo, cancellationToken);
        if (tracking is null)
            return NotFound(ApiResponse<string>.Fail("No shipment found for that tracking number"));

        return Ok(ApiResponse<ShipmentTrackingDto>.Ok(tracking));
    }
}
