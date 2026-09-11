using BharatEMart.Core.Models;
using System;
using System.Collections.Generic;
using System.Text;

namespace BharatEMart.Core.Interfaces
{
    public interface IVehicleOrderService
    {
        Task<bool> BulkInsertAsync(List<VehicleOrderMappingDto> mappings);

        Task<List<VehicleOrderMappingResponseDto>> GetByDateRangeAsync(
            DateOnly fromDate,
            DateOnly toDate
        );
    }
}
