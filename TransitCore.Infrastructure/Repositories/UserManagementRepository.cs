using System.Data;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class UserManagementRepository : IUserManagementService
{
    private readonly SqlDataAccess _db;
    private readonly IPasswordHasher _passwordHasher;

    public UserManagementRepository(SqlDataAccess db, IPasswordHasher passwordHasher)
    {
        _db = db;
        _passwordHasher = passwordHasher;
    }

    public async Task<IReadOnlyList<UserSummaryDto>> GetUsersAsync(UserFilterRequest filter, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@BranchId", (object?)filter.BranchId ?? DBNull.Value),
            new SqlParameter("@DesignationId", (object?)filter.DesignationId ?? DBNull.Value),
            new SqlParameter("@WorkingDesignationId", (object?)filter.WorkingDesignationId ?? DBNull.Value)
        };

        var table = await _db.QueryProcedureAsync("identity.usp_GetUsers", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>().Select(MapSummary).ToList();
    }

    public async Task<UserDetailDto?> GetUserByIdAsync(int userId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@UserId", userId) };
        var dataSet = await _db.QueryProcedureMultipleAsync("identity.usp_GetUserById", parameters, cancellationToken);

        if (dataSet.Tables.Count == 0 || dataSet.Tables[0].Rows.Count == 0)
            return null;

        var row = dataSet.Tables[0].Rows[0];

        var branchIds = dataSet.Tables.Count > 1
            ? dataSet.Tables[1].Rows.Cast<DataRow>().Select(r => Convert.ToInt32(r["BranchId"])).ToList()
            : new List<int>();

        return new UserDetailDto
        {
            Id = Convert.ToInt32(row["Id"]),
            Email = row["Email"].ToString() ?? string.Empty,
            DisplayName = row["DisplayName"].ToString() ?? string.Empty,
            PhoneNo = row["PhoneNo"] as string,
            EmpCode = row["EmpCode"] as string,
            DesignationId = row["DesignationId"] == DBNull.Value ? null : Convert.ToInt32(row["DesignationId"]),
            DesignationName = row["DesignationName"] as string,
            WorkingDesignationId = row["WorkingDesignationId"] == DBNull.Value ? null : Convert.ToInt32(row["WorkingDesignationId"]),
            WorkingDesignationName = row["WorkingDesignationName"] as string,
            RegionId = row["RegionId"] == DBNull.Value ? null : Convert.ToInt32(row["RegionId"]),
            RegionName = row["RegionName"] as string,
            PunchLocation = row["PunchLocation"] as string,
            Shift = row["Shift"] as string,
            Company = row["Company"] as string,
            IsActive = Convert.ToBoolean(row["IsActive"]),
            CreatedAt = Convert.ToDateTime(row["CreatedAt"]),
            CreatedBy = row["CreatedBy"] as string,
            BranchIds = branchIds
        };
    }

    public async Task<int> CreateUserAsync(CreateUserRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var (hash, salt) = _passwordHasher.HashPassword(request.Password);

        var parameters = new[]
        {
            new SqlParameter("@Email", request.Email),
            new SqlParameter("@PasswordHash", hash),
            new SqlParameter("@PasswordSalt", salt),
            new SqlParameter("@DisplayName", request.DisplayName),
            new SqlParameter("@PhoneNo", (object?)request.PhoneNo ?? DBNull.Value),
            new SqlParameter("@EmpCode", (object?)request.EmpCode ?? DBNull.Value),
            new SqlParameter("@DesignationId", (object?)request.DesignationId ?? DBNull.Value),
            new SqlParameter("@WorkingDesignationId", (object?)request.WorkingDesignationId ?? DBNull.Value),
            new SqlParameter("@RegionId", (object?)request.RegionId ?? DBNull.Value),
            new SqlParameter("@PunchLocation", (object?)request.PunchLocation ?? DBNull.Value),
            new SqlParameter("@Shift", (object?)request.Shift ?? DBNull.Value),
            new SqlParameter("@Company", (object?)request.Company ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy),
            BuildBranchesParameter(request.BranchIds)
        };

        var newUserId = await _db.ExecuteScalarProcedureAsync("identity.usp_InsertUser", parameters, cancellationToken);
        return Convert.ToInt32(newUserId);
    }

    public async Task<bool> UpdateUserAsync(UpdateUserRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@UserId", request.UserId),
            new SqlParameter("@DisplayName", request.DisplayName),
            new SqlParameter("@PhoneNo", (object?)request.PhoneNo ?? DBNull.Value),
            new SqlParameter("@DesignationId", (object?)request.DesignationId ?? DBNull.Value),
            new SqlParameter("@WorkingDesignationId", (object?)request.WorkingDesignationId ?? DBNull.Value),
            new SqlParameter("@RegionId", (object?)request.RegionId ?? DBNull.Value),
            new SqlParameter("@PunchLocation", (object?)request.PunchLocation ?? DBNull.Value),
            new SqlParameter("@Shift", (object?)request.Shift ?? DBNull.Value),
            new SqlParameter("@Company", (object?)request.Company ?? DBNull.Value),
            new SqlParameter("@ModifiedBy", modifiedBy),
            BuildBranchesParameter(request.BranchIds),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("identity.usp_UpdateUser", parameters, cancellationToken);

        return isUpdatedParam.Value is bool b && b;
    }

    private static UserSummaryDto MapSummary(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        Email = row["Email"].ToString() ?? string.Empty,
        DisplayName = row["DisplayName"].ToString() ?? string.Empty,
        EmpCode = row["EmpCode"] as string,
        DesignationId = row["DesignationId"] == DBNull.Value ? null : Convert.ToInt32(row["DesignationId"]),
        DesignationName = row["DesignationName"] as string,
        WorkingDesignationId = row["WorkingDesignationId"] == DBNull.Value ? null : Convert.ToInt32(row["WorkingDesignationId"]),
        WorkingDesignationName = row["WorkingDesignationName"] as string,
        RegionId = row["RegionId"] == DBNull.Value ? null : Convert.ToInt32(row["RegionId"]),
        RegionName = row["RegionName"] as string,
        PunchLocation = row["PunchLocation"] as string,
        Shift = row["Shift"] as string,
        Company = row["Company"] as string,
        IsActive = Convert.ToBoolean(row["IsActive"]),
        BranchNames = row["BranchNames"] == DBNull.Value
            ? Array.Empty<string>()
            : row["BranchNames"]!.ToString()!.Split(',', StringSplitOptions.RemoveEmptyEntries)
    };

    private static SqlParameter BuildBranchesParameter(IEnumerable<int> branchIds)
    {
        var table = new DataTable();
        table.Columns.Add("Id", typeof(int));
        foreach (var id in branchIds)
            table.Rows.Add(id);

        return new SqlParameter("@Branches", SqlDbType.Structured)
        {
            TypeName = "identity.IntList_TVP",
            Value = table
        };
    }
}
