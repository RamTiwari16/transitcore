using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace TransitCore.Infrastructure.Ado;

/// <summary>
/// Thin ADO.NET wrapper around a single named connection string. Named
/// "SqlDataAccess" (not "DbContext") so it can never be confused with, or
/// collide with, an EF Core DbContext — this codebase has none.
/// </summary>
public class SqlDataAccess
{
    private readonly string _connectionString;

    public SqlDataAccess(IConfiguration configuration, string connectionStringName)
    {
        if (string.IsNullOrWhiteSpace(connectionStringName))
            throw new ArgumentException("Connection string name is required", nameof(connectionStringName));

        _connectionString = configuration.GetConnectionString(connectionStringName)
            ?? throw new InvalidOperationException($"Connection string '{connectionStringName}' not found.");
    }

    public async Task<DataTable> QueryProcedureAsync(
        string procedureName,
        SqlParameter[]? parameters = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(procedureName, connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        if (parameters is not null)
            command.Parameters.AddRange(parameters);

        var table = new DataTable();
        using var adapter = new SqlDataAdapter(command);
        adapter.Fill(table);
        return table;
    }

    public async Task<DataSet> QueryProcedureMultipleAsync(
        string procedureName,
        SqlParameter[]? parameters = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(procedureName, connection)
        {
            CommandType = CommandType.StoredProcedure,
            CommandTimeout = 300
        };

        if (parameters is not null)
            command.Parameters.AddRange(parameters);

        var dataSet = new DataSet();
        using var adapter = new SqlDataAdapter(command);
        adapter.Fill(dataSet);
        return dataSet;
    }

    public async Task<object?> ExecuteScalarProcedureAsync(
        string procedureName,
        SqlParameter[]? parameters = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(procedureName, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        if (parameters is not null)
            command.Parameters.AddRange(parameters);

        return await command.ExecuteScalarAsync(cancellationToken);
    }

    public async Task<int> ExecuteNonQueryProcedureAsync(
        string procedureName,
        SqlParameter[]? parameters = null,
        CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(procedureName, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        if (parameters is not null)
            command.Parameters.AddRange(parameters);

        return await command.ExecuteNonQueryAsync(cancellationToken);
    }
}
