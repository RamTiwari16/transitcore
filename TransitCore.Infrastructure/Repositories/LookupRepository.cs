using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class LookupRepository : ILookupService
{
    private readonly SqlDataAccess _db;

    public LookupRepository(SqlDataAccess db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<RegionDto>> GetRegionsAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("lookup.usp_GetRegions", cancellationToken: cancellationToken);

        return table.Rows.Cast<System.Data.DataRow>()
            .Select(row => new RegionDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Name = row["Name"].ToString() ?? string.Empty
            })
            .ToList();
    }

    public async Task<IReadOnlyList<BranchDto>> GetBranchesAsync(int? regionId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@RegionId", (object?)regionId ?? DBNull.Value) };
        var table = await _db.QueryProcedureAsync("lookup.usp_GetBranches", parameters, cancellationToken);

        return table.Rows.Cast<System.Data.DataRow>()
            .Select(row => new BranchDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Name = row["Name"].ToString() ?? string.Empty,
                RegionId = Convert.ToInt32(row["RegionId"]),
                RegionName = row["RegionName"].ToString() ?? string.Empty
            })
            .ToList();
    }

    public async Task<IReadOnlyList<DesignationDto>> GetDesignationsAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("lookup.usp_GetDesignations", cancellationToken: cancellationToken);

        return table.Rows.Cast<System.Data.DataRow>()
            .Select(row => new DesignationDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Code = row["Code"].ToString() ?? string.Empty,
                Name = row["Name"].ToString() ?? string.Empty
            })
            .ToList();
    }

    public async Task<IReadOnlyList<WorkingDesignationDto>> GetWorkingDesignationsAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("lookup.usp_GetWorkingDesignations", cancellationToken: cancellationToken);

        return table.Rows.Cast<System.Data.DataRow>()
            .Select(row => new WorkingDesignationDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Name = row["Name"].ToString() ?? string.Empty
            })
            .ToList();
    }

    public async Task<IReadOnlyList<StatusCodeDto>> GetStatusCodesAsync(string category, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@Category", category) };
        var table = await _db.QueryProcedureAsync("lookup.usp_GetStatusCodes", parameters, cancellationToken);

        return table.Rows.Cast<System.Data.DataRow>()
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
}
