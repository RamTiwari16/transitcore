using System.Data;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class SearchRepository : ISearchService
{
    private readonly SqlDataAccess _db;

    public SearchRepository(SqlDataAccess db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<SearchResultDto>> SearchAsync(string term, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(term) || term.Trim().Length < 2)
            return Array.Empty<SearchResultDto>();

        var parameters = new[] { new SqlParameter("@SearchTerm", term.Trim()) };
        var table = await _db.QueryProcedureAsync("dbo.usp_GlobalSearch", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new SearchResultDto
            {
                EntityType = row["EntityType"].ToString() ?? string.Empty,
                EntityId = Convert.ToInt32(row["EntityId"]),
                Label = row["Label"].ToString() ?? string.Empty,
                SubLabel = row["SubLabel"] == DBNull.Value ? null : row["SubLabel"].ToString(),
            })
            .ToList();
    }
}
