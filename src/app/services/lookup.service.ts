import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import {
  BranchModel,
  DesignationModel,
  RegionModel,
  StatusCodeModel,
  WorkingDesignationModel,
} from '../models/lookup.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class LookupService {
  private readonly api = inject(ApiService);

  getRegions(): Observable<RegionModel[]> {
    return this.api
      .get<ApiResponse<RegionModel[]>>(ApiRoutes.Regions)
      .pipe(map((res) => res.data));
  }

  getBranches(regionId?: number): Observable<BranchModel[]> {
    return this.api
      .get<ApiResponse<BranchModel[]>>(ApiRoutes.Branches, regionId ? { regionId } : undefined)
      .pipe(map((res) => res.data));
  }

  getDesignations(): Observable<DesignationModel[]> {
    return this.api
      .get<ApiResponse<DesignationModel[]>>(ApiRoutes.Designations)
      .pipe(map((res) => res.data));
  }

  getWorkingDesignations(): Observable<WorkingDesignationModel[]> {
    return this.api
      .get<ApiResponse<WorkingDesignationModel[]>>(ApiRoutes.WorkingDesignations)
      .pipe(map((res) => res.data));
  }

  getStatusCodes(category: string): Observable<StatusCodeModel[]> {
    return this.api
      .get<ApiResponse<StatusCodeModel[]>>(ApiRoutes.StatusCodes, { category })
      .pipe(map((res) => res.data));
  }
}
