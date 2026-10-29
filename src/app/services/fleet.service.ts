import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import { PagedResult } from '../models/paged-result';
import {
  CreateDriverLicenseRequest,
  CreateDriverRequest,
  CreateFuelLogRequest,
  CreateMaintenanceRecordRequest,
  CreateVehicleDocumentRequest,
  CreateVehicleRequest,
  DriverDetailModel,
  DriverLicenseModel,
  DriverModel,
  DriverPerformanceModel,
  DriverSettlementModel,
  ExpiringDriverLicenseModel,
  ExpiringVehicleDocumentModel,
  FleetUtilisationModel,
  FuelLogModel,
  MaintenanceRecordModel,
  UpdateDriverRequest,
  UpdateVehicleRequest,
  VehicleDocumentModel,
  VehicleModel,
  VehicleTypeModel,
} from '../models/fleet.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class FleetService {
  private readonly api = inject(ApiService);

  getVehicleTypes(): Observable<VehicleTypeModel[]> {
    return this.api
      .get<ApiResponse<VehicleTypeModel[]>>(ApiRoutes.VehicleTypes)
      .pipe(map((res) => res.data));
  }

  getVehicles(
    pageNumber = 1,
    pageSize = 25,
    statusId?: number,
    vehicleTypeId?: number,
  ): Observable<PagedResult<VehicleModel>> {
    return this.api
      .get<ApiResponse<PagedResult<VehicleModel>>>(ApiRoutes.Vehicles, {
        pageNumber,
        pageSize,
        statusId,
        vehicleTypeId,
      })
      .pipe(map((res) => res.data));
  }

  getVehicleById(vehicleId: number): Observable<VehicleModel> {
    return this.api
      .get<ApiResponse<VehicleModel>>(`${ApiRoutes.Vehicles}/${vehicleId}`)
      .pipe(map((res) => res.data));
  }

  createVehicle(request: CreateVehicleRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.Vehicles, request)
      .pipe(map((res) => res.data));
  }

  updateVehicle(request: UpdateVehicleRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.Vehicles, request).pipe(map(() => undefined));
  }

  getDrivers(statusId?: number): Observable<DriverModel[]> {
    return this.api
      .get<ApiResponse<DriverModel[]>>(ApiRoutes.Drivers, statusId ? { statusId } : undefined)
      .pipe(map((res) => res.data));
  }

  createDriver(request: CreateDriverRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.Drivers, request)
      .pipe(map((res) => res.data));
  }

  getDriverById(driverId: number): Observable<DriverDetailModel> {
    return this.api
      .get<ApiResponse<DriverDetailModel>>(`${ApiRoutes.Drivers}/${driverId}`)
      .pipe(map((res) => res.data));
  }

  updateDriver(request: UpdateDriverRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.Drivers, request).pipe(map(() => undefined));
  }

  getFleetUtilisation(fromDate: string, toDate: string): Observable<FleetUtilisationModel[]> {
    return this.api
      .get<ApiResponse<FleetUtilisationModel[]>>(ApiRoutes.FleetUtilisation, { fromDate, toDate })
      .pipe(map((res) => res.data));
  }

  // ---- Vehicle documents ----

  getVehicleDocuments(vehicleId: number): Observable<VehicleDocumentModel[]> {
    return this.api
      .get<ApiResponse<VehicleDocumentModel[]>>(`${ApiRoutes.Vehicles}/${vehicleId}/documents`)
      .pipe(map((res) => res.data));
  }

  createVehicleDocument(vehicleId: number, request: CreateVehicleDocumentRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Vehicles}/${vehicleId}/documents`, request)
      .pipe(map((res) => res.data));
  }

  deleteVehicleDocument(documentId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.VehicleDocuments}/${documentId}`)
      .pipe(map(() => undefined));
  }

  getExpiringVehicleDocuments(daysAhead = 30): Observable<ExpiringVehicleDocumentModel[]> {
    return this.api
      .get<ApiResponse<ExpiringVehicleDocumentModel[]>>(`${ApiRoutes.VehicleDocuments}/expiring`, { daysAhead })
      .pipe(map((res) => res.data));
  }

  // ---- Maintenance records ----

  getMaintenanceRecords(vehicleId: number): Observable<MaintenanceRecordModel[]> {
    return this.api
      .get<ApiResponse<MaintenanceRecordModel[]>>(`${ApiRoutes.Vehicles}/${vehicleId}/maintenance`)
      .pipe(map((res) => res.data));
  }

  createMaintenanceRecord(vehicleId: number, request: CreateMaintenanceRecordRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Vehicles}/${vehicleId}/maintenance`, request)
      .pipe(map((res) => res.data));
  }

  deleteMaintenanceRecord(maintenanceId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.Maintenance}/${maintenanceId}`)
      .pipe(map(() => undefined));
  }

  // ---- Fuel logs ----

  getFuelLogs(vehicleId: number): Observable<FuelLogModel[]> {
    return this.api
      .get<ApiResponse<FuelLogModel[]>>(`${ApiRoutes.Vehicles}/${vehicleId}/fuel-logs`)
      .pipe(map((res) => res.data));
  }

  createFuelLog(vehicleId: number, request: CreateFuelLogRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Vehicles}/${vehicleId}/fuel-logs`, request)
      .pipe(map((res) => res.data));
  }

  deleteFuelLog(fuelLogId: number): Observable<void> {
    return this.api.delete<ApiResponse<string>>(`${ApiRoutes.FuelLogs}/${fuelLogId}`).pipe(map(() => undefined));
  }

  // ---- Driver licenses ----

  getDriverLicenses(driverId: number): Observable<DriverLicenseModel[]> {
    return this.api
      .get<ApiResponse<DriverLicenseModel[]>>(`${ApiRoutes.Drivers}/${driverId}/licenses`)
      .pipe(map((res) => res.data));
  }

  createDriverLicense(driverId: number, request: CreateDriverLicenseRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Drivers}/${driverId}/licenses`, request)
      .pipe(map((res) => res.data));
  }

  deleteDriverLicense(licenseId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.DriverLicenses}/${licenseId}`)
      .pipe(map(() => undefined));
  }

  getExpiringDriverLicenses(daysAhead = 30): Observable<ExpiringDriverLicenseModel[]> {
    return this.api
      .get<ApiResponse<ExpiringDriverLicenseModel[]>>(`${ApiRoutes.DriverLicenses}/expiring`, { daysAhead })
      .pipe(map((res) => res.data));
  }

  // ---- Driver performance ----

  getDriverPerformance(driverId: number): Observable<DriverPerformanceModel> {
    return this.api
      .get<ApiResponse<DriverPerformanceModel>>(`${ApiRoutes.Drivers}/${driverId}/performance`)
      .pipe(map((res) => res.data));
  }

  getDriverSettlement(driverId: number): Observable<DriverSettlementModel> {
    return this.api
      .get<ApiResponse<DriverSettlementModel>>(`${ApiRoutes.Drivers}/${driverId}/settlement`)
      .pipe(map((res) => res.data));
  }
}
