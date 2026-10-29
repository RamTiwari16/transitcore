import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import { PagedResult } from '../models/paged-result';
import {
  ClaimDetailModel,
  ClaimFilter,
  ClaimModel,
  CreateClaimRequest,
  SettleClaimRequest,
  UpdateClaimRequest,
  UpdateClaimStatusRequest,
} from '../models/claim.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class ClaimService {
  private readonly api = inject(ApiService);

  getClaims(filter: ClaimFilter, pageNumber = 1, pageSize = 25): Observable<PagedResult<ClaimModel>> {
    return this.api
      .get<ApiResponse<PagedResult<ClaimModel>>>(ApiRoutes.Claims, { ...filter, pageNumber, pageSize })
      .pipe(map((res) => res.data));
  }

  getClaimById(claimId: number): Observable<ClaimDetailModel> {
    return this.api
      .get<ApiResponse<ClaimDetailModel>>(`${ApiRoutes.Claims}/${claimId}`)
      .pipe(map((res) => res.data));
  }

  createClaim(request: CreateClaimRequest): Observable<number> {
    return this.api.post<ApiResponse<number>>(ApiRoutes.Claims, request).pipe(map((res) => res.data));
  }

  updateClaim(request: UpdateClaimRequest): Observable<void> {
    return this.api
      .put<ApiResponse<string>>(`${ApiRoutes.Claims}/${request.claimId}`, request)
      .pipe(map(() => undefined));
  }

  updateClaimStatus(request: UpdateClaimStatusRequest): Observable<void> {
    return this.api
      .put<ApiResponse<string>>(`${ApiRoutes.Claims}/${request.claimId}/status`, request)
      .pipe(map(() => undefined));
  }

  settleClaim(request: SettleClaimRequest): Observable<void> {
    return this.api
      .post<ApiResponse<string>>(`${ApiRoutes.Claims}/${request.claimId}/settle`, request)
      .pipe(map(() => undefined));
  }
}
