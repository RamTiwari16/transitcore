import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import { PagedResult } from '../models/paged-result';
import {
  CreateShipmentRequest,
  CreateTripRequest,
  RouteModel,
  ShipmentDetailModel,
  ShipmentFilter,
  ShipmentModel,
  TripDetailModel,
  TripFilter,
  TripModel,
  UpdateTripStatusRequest,
} from '../models/ops.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class OpsService {
  private readonly api = inject(ApiService);

  getRoutes(): Observable<RouteModel[]> {
    return this.api.get<ApiResponse<RouteModel[]>>(ApiRoutes.Routes).pipe(map((res) => res.data));
  }

  getTrips(filter: TripFilter, pageNumber = 1, pageSize = 25): Observable<PagedResult<TripModel>> {
    return this.api
      .get<ApiResponse<PagedResult<TripModel>>>(ApiRoutes.Trips, { ...filter, pageNumber, pageSize })
      .pipe(map((res) => res.data));
  }

  getTripById(tripId: number): Observable<TripDetailModel> {
    return this.api
      .get<ApiResponse<TripDetailModel>>(`${ApiRoutes.Trips}/${tripId}`)
      .pipe(map((res) => res.data));
  }

  createTrip(request: CreateTripRequest): Observable<number> {
    return this.api.post<ApiResponse<number>>(ApiRoutes.Trips, request).pipe(map((res) => res.data));
  }

  updateTripStatus(request: UpdateTripStatusRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.TripStatus, request).pipe(map(() => undefined));
  }

  getShipments(filter: ShipmentFilter): Observable<ShipmentModel[]> {
    return this.api
      .get<ApiResponse<ShipmentModel[]>>(ApiRoutes.Shipments, filter)
      .pipe(map((res) => res.data));
  }

  getShipmentById(shipmentId: number): Observable<ShipmentDetailModel> {
    return this.api
      .get<ApiResponse<ShipmentDetailModel>>(`${ApiRoutes.Shipments}/${shipmentId}`)
      .pipe(map((res) => res.data));
  }

  createShipment(request: CreateShipmentRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.Shipments, request)
      .pipe(map((res) => res.data));
  }
}
