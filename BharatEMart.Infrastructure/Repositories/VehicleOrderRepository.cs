using BharatEMart.Core.Interfaces;
using BharatEMart.Core.Models;
using Microsoft.Data.SqlClient;
using PortalService.Infrastructure.ADO;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace BharatEMart.Infrastructure.Repositories
{
    public class VehicleOrderRepository : IVehicleOrderService
    {
        private readonly DbContext _dbContext;

        public VehicleOrderRepository(DbContext dbContext)
        {
            _dbContext = dbContext;
        }

        public async Task<bool> BulkInsertAsync(List<VehicleOrderMappingDto> mappings)
        {
            if (mappings == null || !mappings.Any())
                throw new Exception("Mapping data is required");

            DataTable dt = new DataTable();

            dt.Columns.Add("VehicleNo", typeof(string));
            dt.Columns.Add("OrderNo", typeof(string));
            dt.Columns.Add("UploadDate", typeof(DateTime));
            dt.Columns.Add("CreatedByEmail", typeof(string));

            foreach (var item in mappings)
            {
                if (string.IsNullOrWhiteSpace(item.VehicleNo))
                    throw new Exception("VehicleNo is required");

                if (string.IsNullOrWhiteSpace(item.OrderNo))
                    throw new Exception("OrderNo is required");

                if (string.IsNullOrWhiteSpace(item.CreatedByEmail))
                    throw new Exception("CreatedByEmail is required");

                dt.Rows.Add(
                    item.VehicleNo,
                    item.OrderNo,
                    item.UploadDate.ToDateTime(TimeOnly.MinValue),
                    item.CreatedByEmail
                );
            }

            var parameter = new SqlParameter("@Mappings", SqlDbType.Structured)
            {
                TypeName = "VehicleOrderMappingType",
                Value = dt
            };

            var result = await _dbContext.ExecuteNonQueryWithProcAsync(
                "SP_BulkInsertVehicleOrderMapping",
                parameter
            );

            return result > 0;
        }

        public async Task<List<VehicleOrderMappingResponseDto>> GetByDateRangeAsync(
            DateOnly fromDate,
            DateOnly toDate
        )
        {
            var parameters = new[]
            {
                new SqlParameter("@FromDate", fromDate.ToDateTime(TimeOnly.MinValue)),
                new SqlParameter("@ToDate", toDate.ToDateTime(TimeOnly.MinValue))
            };

            var dt = await _dbContext.ReturnDtWithProcAsync(
                "SP_GetVehicleOrderMappingByDateRange",
                parameters
            );

            List<VehicleOrderMappingResponseDto> response =
                new List<VehicleOrderMappingResponseDto>();

            foreach (DataRow row in dt.Rows)
            {
                response.Add(new VehicleOrderMappingResponseDto
                {
                    Id = Convert.ToInt32(row["Id"]),
                    VehicleNo = row["VehicleNo"].ToString(),
                    OrderNo = row["OrderNo"].ToString(),
                    UploadDate = DateOnly.FromDateTime(
                        Convert.ToDateTime(row["UploadDate"])
                    ),
                    CreatedByEmail = row["CreatedByEmail"].ToString(),
                    CreatedAt = Convert.ToDateTime(row["CreatedAt"])
                });
            }

            return response;
        }
    }
}

