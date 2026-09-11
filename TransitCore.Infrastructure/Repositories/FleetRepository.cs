using System.Data;
using Microsoft.Data.SqlClient;
using TransitCore.Application.Interfaces;
using TransitCore.Application.Models;
using TransitCore.Infrastructure.Ado;

namespace TransitCore.Infrastructure.Repositories;

public class FleetRepository : IFleetService
{
    private readonly SqlDataAccess _db;

    public FleetRepository(SqlDataAccess db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<VehicleTypeDto>> GetVehicleTypesAsync(CancellationToken cancellationToken = default)
    {
        var table = await _db.QueryProcedureAsync("fleet.usp_GetVehicleTypes", cancellationToken: cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new VehicleTypeDto
            {
                Id = Convert.ToInt32(row["Id"]),
                Name = row["Name"].ToString() ?? string.Empty,
                Description = row["Description"] as string,
                CapacityKg = Convert.ToDecimal(row["CapacityKg"])
            })
            .ToList();
    }

    public async Task<PagedResult<VehicleDto>> GetVehiclesAsync(int? statusId, int? vehicleTypeId, int pageNumber, int pageSize, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@StatusId", (object?)statusId ?? DBNull.Value),
            new SqlParameter("@VehicleTypeId", (object?)vehicleTypeId ?? DBNull.Value),
            new SqlParameter("@PageNumber", pageNumber),
            new SqlParameter("@PageSize", pageSize)
        };

        var table = await _db.QueryProcedureAsync("fleet.usp_GetVehicles", parameters, cancellationToken);

        var items = table.Rows.Cast<DataRow>().Select(MapVehicle).ToList();
        var totalCount = table.Rows.Count > 0 ? Convert.ToInt32(table.Rows[0]["TotalCount"]) : 0;

        return new PagedResult<VehicleDto>
        {
            Items = items,
            TotalCount = totalCount,
            PageNumber = pageNumber,
            PageSize = pageSize
        };
    }

    public async Task<VehicleDto?> GetVehicleByIdAsync(int vehicleId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@VehicleId", vehicleId) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetVehicleById", parameters, cancellationToken);

        return table.Rows.Count == 0 ? null : MapVehicle(table.Rows[0]);
    }

    public async Task<int> CreateVehicleAsync(CreateVehicleRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@RegistrationNo", request.RegistrationNo),
            new SqlParameter("@VehicleTypeId", request.VehicleTypeId),
            new SqlParameter("@Make", (object?)request.Make ?? DBNull.Value),
            new SqlParameter("@Model", (object?)request.Model ?? DBNull.Value),
            new SqlParameter("@ManufactureYear", (object?)request.ManufactureYear ?? DBNull.Value),
            new SqlParameter("@CapacityKg", request.CapacityKg),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("fleet.usp_InsertVehicle", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> UpdateVehicleAsync(UpdateVehicleRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@VehicleId", request.VehicleId),
            new SqlParameter("@VehicleTypeId", request.VehicleTypeId),
            new SqlParameter("@Make", (object?)request.Make ?? DBNull.Value),
            new SqlParameter("@Model", (object?)request.Model ?? DBNull.Value),
            new SqlParameter("@ManufactureYear", (object?)request.ManufactureYear ?? DBNull.Value),
            new SqlParameter("@CapacityKg", request.CapacityKg),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("fleet.usp_UpdateVehicle", parameters, cancellationToken);

        return isUpdatedParam.Value is bool b && b;
    }

    public async Task<IReadOnlyList<DriverDto>> GetDriversAsync(int? statusId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@StatusId", (object?)statusId ?? DBNull.Value) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetDrivers", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new DriverDto
            {
                Id = Convert.ToInt32(row["Id"]),
                FullName = row["FullName"].ToString() ?? string.Empty,
                PhoneNo = row["PhoneNo"] as string,
                Email = row["Email"] as string,
                HireDate = row["HireDate"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["HireDate"])),
                StatusId = Convert.ToInt32(row["StatusId"]),
                StatusName = row["StatusName"].ToString() ?? string.Empty
            })
            .ToList();
    }

    public async Task<int> CreateDriverAsync(CreateDriverRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@FullName", request.FullName),
            new SqlParameter("@PhoneNo", (object?)request.PhoneNo ?? DBNull.Value),
            new SqlParameter("@Email", (object?)request.Email ?? DBNull.Value),
            new SqlParameter("@DateOfBirth", request.DateOfBirth.HasValue ? request.DateOfBirth.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
            new SqlParameter("@HireDate", request.HireDate.HasValue ? request.HireDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("fleet.usp_InsertDriver", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<IReadOnlyList<FleetUtilisationDto>> GetFleetUtilisationAsync(DateOnly fromDate, DateOnly toDate, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@FromDate", fromDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@ToDate", toDate.ToDateTime(TimeOnly.MinValue))
        };

        var table = await _db.QueryProcedureAsync("fleet.usp_GetFleetUtilisation", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new FleetUtilisationDto
            {
                VehicleId = Convert.ToInt32(row["VehicleId"]),
                RegistrationNo = row["RegistrationNo"].ToString() ?? string.Empty,
                VehicleTypeName = row["VehicleTypeName"].ToString() ?? string.Empty,
                TotalTrips = Convert.ToInt32(row["TotalTrips"]),
                ScheduledHours = Convert.ToDecimal(row["ScheduledHours"]),
                UtilisationPercent = Convert.ToDecimal(row["UtilisationPercent"])
            })
            .ToList();
    }

    private static VehicleDto MapVehicle(DataRow row) => new()
    {
        Id = Convert.ToInt32(row["Id"]),
        RegistrationNo = row["RegistrationNo"].ToString() ?? string.Empty,
        VehicleTypeId = Convert.ToInt32(row["VehicleTypeId"]),
        VehicleTypeName = row["VehicleTypeName"].ToString() ?? string.Empty,
        Make = row["Make"] as string,
        Model = row["Model"] as string,
        ManufactureYear = row["ManufactureYear"] == DBNull.Value ? null : Convert.ToInt32(row["ManufactureYear"]),
        CapacityKg = Convert.ToDecimal(row["CapacityKg"]),
        StatusId = Convert.ToInt32(row["StatusId"]),
        StatusName = row["StatusName"].ToString() ?? string.Empty
    };
}
