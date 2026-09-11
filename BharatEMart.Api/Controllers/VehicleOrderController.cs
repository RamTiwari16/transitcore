using BharatEMart.Core.Interfaces;
using BharatEMart.Core.Models;
using ClosedXML.Excel;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using PortalService.Core.Models;
using System.Security.Claims;

namespace BharatEMart.Api.Controllers
{
    [Authorize]
    [Route("api/[controller]")]
    [ApiController]
    
    public class VehicleOrderController : ControllerBase
    {
        private readonly IVehicleOrderService _repository;

        public VehicleOrderController(
            IVehicleOrderService repository
        )
        {
            _repository = repository;
        }

        [HttpPost("bulk-upload")]
        public async Task<IActionResult> BulkUpload(IFormFile file)
        {
            try
            {
                if (file == null || file.Length == 0)
                {
                    return BadRequest(
                        new ApiResponseDto<string>
                        {
                            Success = false,
                            Message = "Excel file is required"
                        }
                    );
                }

                var extension = Path.GetExtension(file.FileName);

                if (
                    extension.ToLower() != ".xlsx"
                    && extension.ToLower() != ".xls"
                )
                {
                    return BadRequest(
                        new ApiResponseDto<string>
                        {
                            Success = false,
                            Message = "Only Excel files are allowed"
                        }
                    );
                }

                var createdByEmail = User.FindFirst(ClaimTypes.Email)?.Value;

                if (string.IsNullOrWhiteSpace(createdByEmail))
                {
                    return Unauthorized(
                        new ApiResponseDto<string>
                        {
                            Success = false,
                            Message = "Invalid token"
                        }
                    );
                }

                List<VehicleOrderMappingDto> mappings =
                    new List<VehicleOrderMappingDto>();

                List<string> validationErrors =
                    new List<string>();

                using (var stream = new MemoryStream())
                {
                    await file.CopyToAsync(stream);

                    using (var workbook = new XLWorkbook(stream))
                    {
                        var worksheet = workbook.Worksheet(1);

                        var rows = worksheet.RowsUsed().Skip(1);

                        foreach (var row in rows)
                        {
                            var orderNo = row.Cell(1)
                                .GetValue<string>()?
                                .Trim();

                            var vehicleNo = row.Cell(2)
                                .GetValue<string>()?
                                .Trim();

                            
                            if (string.IsNullOrWhiteSpace(vehicleNo))
                            {
                                validationErrors.Add(
                                    $"Row {row.RowNumber()} : VehicleNo is required"
                                );

                                continue;
                            }

                            if (string.IsNullOrWhiteSpace(orderNo))
                            {
                                validationErrors.Add(
                                    $"Row {row.RowNumber()} : OrderNo is required"
                                );

                                continue;
                            }

                            mappings.Add(
                                new VehicleOrderMappingDto
                                {
                                    VehicleNo = vehicleNo,
                                    OrderNo = orderNo,
                                    UploadDate = DateOnly.FromDateTime(DateTime.Now),
                                    CreatedByEmail = createdByEmail
                                }
                            );
                        }
                    }
                }

                if (validationErrors.Any())
                {
                    return BadRequest(
                        new ApiResponseDto<List<string>>
                        {
                            Success = false,
                            Message = "Validation failed",
                            Data = validationErrors
                        }
                    );
                }

                if (!mappings.Any())
                {
                    return BadRequest(
                        new ApiResponseDto<string>
                        {
                            Success = false,
                            Message = "No valid records found"
                        }
                    );
                }

                var result = await _repository.BulkInsertAsync(mappings);

                return Ok(
                    new ApiResponseDto<object>
                    {
                        Success = true,
                        Message = $"{mappings.Count} records uploaded successfully",
                        Data = new
                        {
                            TotalRecords = mappings.Count,
                            UploadedBy = createdByEmail,
                            UploadDate = DateTime.Now.Date
                        }
                    }
                );
            }
            catch (Exception ex)
            {
                return BadRequest(
                    new ApiResponseDto<string>
                    {
                        Success = false,
                        Message = ex.Message
                    }
                );
            }
        }

        [HttpPost("get-by-date-range")]
        public async Task<IActionResult> GetByDateRange(
            [FromBody] DateRangeRequestDto request
        )
        {
            try
            {
                if (request.FromDate > request.ToDate)
                {
                    return BadRequest(
                        new ApiResponseDto<string>
                        {
                            Success = false,
                            Message = "FromDate cannot be greater than ToDate"
                        }
                    );
                }

                var data = await _repository.GetByDateRangeAsync(
                    request.FromDate,
                    request.ToDate
                );

                return Ok(
                    new ApiResponseDto<List<VehicleOrderMappingResponseDto>>
                    {
                        Success = true,
                        Message = "Data fetched successfully",
                        Data = data
                    }
                );
            }
            catch (Exception ex)
            {
                return BadRequest(
                    new ApiResponseDto<string>
                    {
                        Success = false,
                        Message = ex.Message
                    }
                );
            }
        }
    }
}
