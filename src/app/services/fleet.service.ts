import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import { PagedResult } from '../models/paged-result';
import {
  CreateVehicleRequest,
  DriverModel,
  FleetUtilisationModel,
  UpdateVehicleRequest,
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

  getFleetUtilisation(fromDate: string, toDate: string): Observable<FleetUtilisationModel[]> {
    return this.api
      .get<ApiResponse<FleetUtilisationModel[]>>(ApiRoutes.FleetUtilisation, { fromDate, toDate })
      .pipe(map((res) => res.data));
  }
}
