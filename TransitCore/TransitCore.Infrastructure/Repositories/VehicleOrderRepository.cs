using System.Data;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class VehicleOrderRepository : IVehicleOrderService
{
    private readonly SqlDataAccess _db;

    public VehicleOrderRepository(SqlDataAccess db)
    {
        _db = db;
    }

    public async Task<int> BulkInsertAsync(IReadOnlyList<VehicleOrderMappingRow> rows, CancellationToken cancellationToken = default)
    {
        if (rows.Count == 0)
            throw new ArgumentException("At least one row is required", nameof(rows));

        var table = new DataTable();
        table.Columns.Add("VehicleNo", typeof(string));
        table.Columns.Add("OrderNo", typeof(string));
        table.Columns.Add("UploadDate", typeof(DateTime));
        table.Columns.Add("CreatedByEmail", typeof(string));

        foreach (var row in rows)
        {
            table.Rows.Add(row.VehicleNo, row.OrderNo, row.UploadDate.ToDateTime(TimeOnly.MinValue), row.CreatedByEmail);
        }

        var parameter = new SqlParameter("@Mappings", SqlDbType.Structured)
        {
            TypeName = "ops.VehicleOrderMappingType",
            Value = table
        };

        var insertedCount = await _db.ExecuteScalarProcedureAsync(
            "ops.usp_BulkInsertVehicleOrderMapping",
            new[] { parameter },
            cancellationToken);

        return Convert.ToInt32(insertedCount);
    }

    public async Task<IReadOnlyList<VehicleOrderMappingDto>> GetByDateRangeAsync(DateOnly fromDate, DateOnly toDate, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@FromDate", fromDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@ToDate", toDate.ToDateTime(TimeOnly.MinValue))
        };

        var table = await _db.QueryProcedureAsync("ops.usp_GetVehicleOrderMappingByDateRange", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new VehicleOrderMappingDto
            {
                Id = Convert.ToInt32(row["Id"]),
                VehicleNo = row["VehicleNo"].ToString() ?? string.Empty,
                OrderNo = row["OrderNo"].ToString() ?? string.Empty,
                UploadDate = DateOnly.FromDateTime(Convert.ToDateTime(row["UploadDate"])),
                CreatedByEmail = row["CreatedByEmail"].ToString() ?? string.Empty,
                CreatedAt = Convert.ToDateTime(row["CreatedAt"])
            })
            .ToList();
    }
}
