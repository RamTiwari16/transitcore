using System.Security.Claims;
using ClosedXML.Excel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;

namespace TransitCore.Api.Controllers;

[Authorize]
[Route("api/v1/[controller]")]
[ApiController]
public class VehicleOrderController : ControllerBase
{
    private readonly IVehicleOrderService _vehicleOrderService;

    public VehicleOrderController(IVehicleOrderService vehicleOrderService)
    {
        _vehicleOrderService = vehicleOrderService;
    }

    [HttpPost("bulk-upload")]
    public async Task<IActionResult> BulkUpload(IFormFile file, CancellationToken cancellationToken)
    {
        if (file is null || file.Length == 0)
            return BadRequest(ApiResponse<string>.Fail("Excel file is required"));

        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (extension != ".xlsx" && extension != ".xls")
            return BadRequest(ApiResponse<string>.Fail("Only Excel files are allowed"));

        var createdByEmail = User.FindFirst(ClaimTypes.Email)?.Value;
        if (string.IsNullOrWhiteSpace(createdByEmail))
            return Unauthorized(ApiResponse<string>.Fail("Invalid token"));

        var rows = new List<VehicleOrderMappingRow>();
        var validationErrors = new List<string>();

        await using (var stream = new MemoryStream())
        {
            await file.CopyToAsync(stream, cancellationToken);

            using var workbook = new XLWorkbook(stream);
            var worksheet = workbook.Worksheet(1);

            foreach (var row in worksheet.RowsUsed().Skip(1))
            {
                var orderNo = row.Cell(1).GetValue<string>()?.Trim();
                var vehicleNo = row.Cell(2).GetValue<string>()?.Trim();

                if (string.IsNullOrWhiteSpace(vehicleNo))
                {
                    validationErrors.Add($"Row {row.RowNumber()}: VehicleNo is required");
                    continue;
                }

                if (string.IsNullOrWhiteSpace(orderNo))
                {
                    validationErrors.Add($"Row {row.RowNumber()}: OrderNo is required");
                    continue;
                }

                rows.Add(new VehicleOrderMappingRow
                {
                    VehicleNo = vehicleNo,
                    OrderNo = orderNo,
                    UploadDate = DateOnly.FromDateTime(DateTime.UtcNow),
                    CreatedByEmail = createdByEmail
                });
            }
        }

        if (validationErrors.Count > 0)
        {
            return BadRequest(new ApiResponse<IReadOnlyList<string>>
            {
                Success = false,
                Message = "Validation failed",
                Data = validationErrors
            });
        }

        if (rows.Count == 0)
            return BadRequest(ApiResponse<string>.Fail("No valid records found"));

        var insertedCount = await _vehicleOrderService.BulkInsertAsync(rows, cancellationToken);

        var result = new BulkUploadResult
        {
            TotalRecords = insertedCount,
            UploadedBy = createdByEmail,
            UploadDate = DateOnly.FromDateTime(DateTime.UtcNow)
        };

        return Ok(ApiResponse<BulkUploadResult>.Ok(result, $"{insertedCount} records uploaded successfully"));
    }

    [HttpPost("get-by-date-range")]
    public async Task<IActionResult> GetByDateRange([FromBody] DateRangeRequest request, CancellationToken cancellationToken)
    {
        if (request.FromDate > request.ToDate)
            return BadRequest(ApiResponse<string>.Fail("FromDate cannot be greater than ToDate"));

        var data = await _vehicleOrderService.GetByDateRangeAsync(request.FromDate, request.ToDate, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<VehicleOrderMappingDto>>.Ok(data, "Data fetched successfully"));
    }
}
