import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import {
  DriverSettlementSummaryModel,
  EmptyKmReportModel,
  FleetUtilisationTrendModel,
  RevenueByPeriodModel,
  ShipmentVolumeTrendModel,
  VehicleAvailabilityModel,
} from '../models/reports.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class ReportsService {
  private readonly api = inject(ApiService);

  getRevenueByPeriod(monthsBack = 12): Observable<RevenueByPeriodModel[]> {
    return this.api
      .get<ApiResponse<RevenueByPeriodModel[]>>(ApiRoutes.RevenueByPeriod, { monthsBack })
      .pipe(map((res) => res.data));
  }

  getDriverSettlementSummary(): Observable<DriverSettlementSummaryModel[]> {
    return this.api
      .get<ApiResponse<DriverSettlementSummaryModel[]>>(ApiRoutes.DriverSettlementSummary)
      .pipe(map((res) => res.data));
  }

  getFleetUtilisationTrend(monthsBack = 6): Observable<FleetUtilisationTrendModel[]> {
    return this.api
      .get<ApiResponse<FleetUtilisationTrendModel[]>>(ApiRoutes.FleetUtilisationTrend, { monthsBack })
      .pipe(map((res) => res.data));
  }

  getShipmentVolumeTrend(monthsBack = 12): Observable<ShipmentVolumeTrendModel[]> {
    return this.api
      .get<ApiResponse<ShipmentVolumeTrendModel[]>>(ApiRoutes.ShipmentVolumeTrend, { monthsBack })
      .pipe(map((res) => res.data));
  }

  getEmptyKmReport(fromDate: string, toDate: string): Observable<EmptyKmReportModel[]> {
    return this.api
      .get<ApiResponse<EmptyKmReportModel[]>>(ApiRoutes.EmptyKmReport, { fromDate, toDate })
      .pipe(map((res) => res.data));
  }

  getVehiclesBecomingAvailable(): Observable<VehicleAvailabilityModel[]> {
    return this.api
      .get<ApiResponse<VehicleAvailabilityModel[]>>(ApiRoutes.VehiclesBecomingAvailable)
      .pipe(map((res) => res.data));
  }
}
