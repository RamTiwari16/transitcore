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
                CapacityKg = Convert.ToDecimal(row["CapacityKg"]),
                CapacityCbm = Convert.ToDecimal(row["CapacityCbm"])
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
            new SqlParameter("@CapacityCbm", request.CapacityCbm),
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
            new SqlParameter("@CapacityCbm", request.CapacityCbm),
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

    public async Task<DriverDetailDto?> GetDriverByIdAsync(int driverId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@DriverId", driverId) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetDriverById", parameters, cancellationToken);

        if (table.Rows.Count == 0) return null;

        var row = table.Rows[0];
        return new DriverDetailDto
        {
            Id = Convert.ToInt32(row["Id"]),
            FullName = row["FullName"].ToString() ?? string.Empty,
            PhoneNo = row["PhoneNo"] as string,
            Email = row["Email"] as string,
            DateOfBirth = row["DateOfBirth"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["DateOfBirth"])),
            HireDate = row["HireDate"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["HireDate"])),
            StatusId = Convert.ToInt32(row["StatusId"]),
            StatusName = row["StatusName"].ToString() ?? string.Empty
        };
    }

    public async Task<bool> UpdateDriverAsync(UpdateDriverRequest request, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit) { Direction = ParameterDirection.Output };

        var parameters = new[]
        {
            new SqlParameter("@DriverId", request.DriverId),
            new SqlParameter("@FullName", request.FullName),
            new SqlParameter("@PhoneNo", (object?)request.PhoneNo ?? DBNull.Value),
            new SqlParameter("@Email", (object?)request.Email ?? DBNull.Value),
            new SqlParameter("@DateOfBirth", request.DateOfBirth.HasValue ? request.DateOfBirth.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
            new SqlParameter("@HireDate", request.HireDate.HasValue ? request.HireDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
            new SqlParameter("@StatusId", request.StatusId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            isUpdatedParam
        };

        await _db.ExecuteNonQueryProcedureAsync("fleet.usp_UpdateDriver", parameters, cancellationToken);

        return isUpdatedParam.Value is bool b && b;
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

    // ---- Vehicle documents ----

    public async Task<IReadOnlyList<VehicleDocumentDto>> GetVehicleDocumentsAsync(int vehicleId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@VehicleId", vehicleId) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetVehicleDocuments", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new VehicleDocumentDto
            {
                Id = Convert.ToInt32(row["Id"]),
                VehicleId = Convert.ToInt32(row["VehicleId"]),
                DocumentType = row["DocumentType"].ToString() ?? string.Empty,
                DocumentNo = row["DocumentNo"] as string,
                IssuedDate = row["IssuedDate"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["IssuedDate"])),
                ExpiryDate = row["ExpiryDate"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["ExpiryDate"]))
            })
            .ToList();
    }

    public async Task<int> CreateVehicleDocumentAsync(CreateVehicleDocumentRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@VehicleId", request.VehicleId),
            new SqlParameter("@DocumentType", request.DocumentType),
            new SqlParameter("@DocumentNo", (object?)request.DocumentNo ?? DBNull.Value),
            new SqlParameter("@IssuedDate", request.IssuedDate.HasValue ? request.IssuedDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
            new SqlParameter("@ExpiryDate", request.ExpiryDate.HasValue ? request.ExpiryDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("fleet.usp_InsertVehicleDocument", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteVehicleDocumentAsync(int documentId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@DocumentId", documentId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("fleet.usp_DeleteVehicleDocument", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<IReadOnlyList<ExpiringVehicleDocumentDto>> GetExpiringVehicleDocumentsAsync(int daysAhead, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@DaysAhead", daysAhead) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetExpiringVehicleDocuments", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new ExpiringVehicleDocumentDto
            {
                Id = Convert.ToInt32(row["Id"]),
                VehicleId = Convert.ToInt32(row["VehicleId"]),
                RegistrationNo = row["RegistrationNo"].ToString() ?? string.Empty,
                DocumentType = row["DocumentType"].ToString() ?? string.Empty,
                DocumentNo = row["DocumentNo"] as string,
                ExpiryDate = DateOnly.FromDateTime(Convert.ToDateTime(row["ExpiryDate"]))
            })
            .ToList();
    }

    // ---- Maintenance records ----

    public async Task<IReadOnlyList<MaintenanceRecordDto>> GetMaintenanceRecordsAsync(int vehicleId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@VehicleId", vehicleId) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetMaintenanceRecords", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new MaintenanceRecordDto
            {
                Id = Convert.ToInt32(row["Id"]),
                VehicleId = Convert.ToInt32(row["VehicleId"]),
                ServiceDate = DateOnly.FromDateTime(Convert.ToDateTime(row["ServiceDate"])),
                Description = row["Description"] as string,
                Cost = Convert.ToDecimal(row["Cost"]),
                OdometerKm = row["OdometerKm"] == DBNull.Value ? null : Convert.ToInt32(row["OdometerKm"]),
                PerformedBy = row["PerformedBy"] as string
            })
            .ToList();
    }

    public async Task<int> CreateMaintenanceRecordAsync(CreateMaintenanceRecordRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@VehicleId", request.VehicleId),
            new SqlParameter("@ServiceDate", request.ServiceDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@Description", (object?)request.Description ?? DBNull.Value),
            new SqlParameter("@Cost", request.Cost),
            new SqlParameter("@OdometerKm", (object?)request.OdometerKm ?? DBNull.Value),
            new SqlParameter("@PerformedBy", (object?)request.PerformedBy ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("fleet.usp_InsertMaintenanceRecord", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteMaintenanceRecordAsync(int maintenanceId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@MaintenanceId", maintenanceId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("fleet.usp_DeleteMaintenanceRecord", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Fuel logs ----

    public async Task<IReadOnlyList<FuelLogDto>> GetFuelLogsAsync(int vehicleId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@VehicleId", vehicleId) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetFuelLogs", parameters, cancellationToken);

        // Proc orders ascending by FuelDate/OdometerKm - km/L for each entry
        // is the distance since the previous entry's odometer reading,
        // divided by this fill's liters. Returned newest-first to match how
        // the other log-style lists (maintenance) are ordered.
        var logs = table.Rows.Cast<DataRow>()
            .Select(row => new FuelLogDto
            {
                Id = Convert.ToInt32(row["Id"]),
                VehicleId = Convert.ToInt32(row["VehicleId"]),
                FuelDate = DateOnly.FromDateTime(Convert.ToDateTime(row["FuelDate"])),
                Liters = Convert.ToDecimal(row["Liters"]),
                Cost = Convert.ToDecimal(row["Cost"]),
                OdometerKm = row["OdometerKm"] == DBNull.Value ? null : Convert.ToInt32(row["OdometerKm"])
            })
            .ToList();

        int? previousOdometer = null;
        foreach (var log in logs)
        {
            if (previousOdometer.HasValue && log.OdometerKm.HasValue && log.Liters > 0)
            {
                var distance = log.OdometerKm.Value - previousOdometer.Value;
                if (distance > 0)
                    log.KmPerLiter = Math.Round(distance / log.Liters, 2);
            }

            if (log.OdometerKm.HasValue)
                previousOdometer = log.OdometerKm;
        }

        logs.Reverse();
        return logs;
    }

    public async Task<int> CreateFuelLogAsync(CreateFuelLogRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@VehicleId", request.VehicleId),
            new SqlParameter("@FuelDate", request.FuelDate.ToDateTime(TimeOnly.MinValue)),
            new SqlParameter("@Liters", request.Liters),
            new SqlParameter("@Cost", request.Cost),
            new SqlParameter("@OdometerKm", (object?)request.OdometerKm ?? DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("fleet.usp_InsertFuelLog", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteFuelLogAsync(int fuelLogId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@FuelLogId", fuelLogId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("fleet.usp_DeleteFuelLog", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    // ---- Driver licenses ----

    public async Task<IReadOnlyList<DriverLicenseDto>> GetDriverLicensesAsync(int driverId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@DriverId", driverId) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetDriverLicenses", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new DriverLicenseDto
            {
                Id = Convert.ToInt32(row["Id"]),
                DriverId = Convert.ToInt32(row["DriverId"]),
                LicenseNo = row["LicenseNo"].ToString() ?? string.Empty,
                LicenseType = row["LicenseType"] as string,
                IssuedDate = row["IssuedDate"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["IssuedDate"])),
                ExpiryDate = row["ExpiryDate"] == DBNull.Value ? null : DateOnly.FromDateTime(Convert.ToDateTime(row["ExpiryDate"]))
            })
            .ToList();
    }

    public async Task<int> CreateDriverLicenseAsync(CreateDriverLicenseRequest request, string createdBy, CancellationToken cancellationToken = default)
    {
        var parameters = new[]
        {
            new SqlParameter("@DriverId", request.DriverId),
            new SqlParameter("@LicenseNo", request.LicenseNo),
            new SqlParameter("@LicenseType", (object?)request.LicenseType ?? DBNull.Value),
            new SqlParameter("@IssuedDate", request.IssuedDate.HasValue ? request.IssuedDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
            new SqlParameter("@ExpiryDate", request.ExpiryDate.HasValue ? request.ExpiryDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value),
            new SqlParameter("@CreatedBy", createdBy)
        };

        var newId = await _db.ExecuteScalarProcedureAsync("fleet.usp_InsertDriverLicense", parameters, cancellationToken);
        return Convert.ToInt32(newId);
    }

    public async Task<bool> DeleteDriverLicenseAsync(int licenseId, string modifiedBy, CancellationToken cancellationToken = default)
    {
        var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
        var parameters = new[]
        {
            new SqlParameter("@LicenseId", licenseId),
            new SqlParameter("@ModifiedBy", modifiedBy),
            successParam
        };

        await _db.ExecuteNonQueryProcedureAsync("fleet.usp_DeleteDriverLicense", parameters, cancellationToken);
        return successParam.Value is bool b && b;
    }

    public async Task<IReadOnlyList<ExpiringDriverLicenseDto>> GetExpiringDriverLicensesAsync(int daysAhead, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@DaysAhead", daysAhead) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetExpiringDriverLicenses", parameters, cancellationToken);

        return table.Rows.Cast<DataRow>()
            .Select(row => new ExpiringDriverLicenseDto
            {
                Id = Convert.ToInt32(row["Id"]),
                DriverId = Convert.ToInt32(row["DriverId"]),
                DriverName = row["DriverName"].ToString() ?? string.Empty,
                LicenseType = row["LicenseType"] as string,
                LicenseNo = row["LicenseNo"].ToString() ?? string.Empty,
                ExpiryDate = DateOnly.FromDateTime(Convert.ToDateTime(row["ExpiryDate"]))
            })
            .ToList();
    }

    // ---- Driver performance ----

    public async Task<DriverPerformanceDto> GetDriverPerformanceAsync(int driverId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@DriverId", driverId) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetDriverPerformance", parameters, cancellationToken);

        if (table.Rows.Count == 0)
            return new DriverPerformanceDto { DriverId = driverId };

        var row = table.Rows[0];
        var completedTrips = Convert.ToInt32(row["CompletedTrips"]);
        var onTimeTrips = Convert.ToInt32(row["OnTimeTrips"]);

        return new DriverPerformanceDto
        {
            DriverId = driverId,
            TotalTrips = Convert.ToInt32(row["TotalTrips"]),
            CompletedTrips = completedTrips,
            OnTimeTrips = onTimeTrips,
            DelayedTrips = Convert.ToInt32(row["DelayedTrips"]),
            TotalDistanceKm = Convert.ToDecimal(row["TotalDistanceKm"]),
            OnTimePercent = completedTrips > 0 ? Math.Round(100m * onTimeTrips / completedTrips, 1) : null
        };
    }

    public async Task<DriverSettlementDto> GetDriverSettlementAsync(int driverId, CancellationToken cancellationToken = default)
    {
        var parameters = new[] { new SqlParameter("@DriverId", driverId) };
        var table = await _db.QueryProcedureAsync("fleet.usp_GetDriverSettlement", parameters, cancellationToken);

        if (table.Rows.Count == 0)
            return new DriverSettlementDto { DriverId = driverId };

        var row = table.Rows[0];
        return new DriverSettlementDto
        {
            DriverId = driverId,
            TotalAdvances = Convert.ToDecimal(row["TotalAdvances"]),
            TotalExpenses = Convert.ToDecimal(row["TotalExpenses"]),
            TripsWithActivity = Convert.ToInt32(row["TripsWithActivity"])
        };
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
        CapacityCbm = Convert.ToDecimal(row["CapacityCbm"]),
        StatusId = Convert.ToInt32(row["StatusId"]),
        StatusName = row["StatusName"].ToString() ?? string.Empty
    };
}
