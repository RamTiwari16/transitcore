import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import {
  CountryModel,
  CreateBranchRequest,
  CreateCityRequest,
  CreateCountryRequest,
  CreateDesignationRequest,
  CreateRegionRequest,
  CreateStatusCodeRequest,
  CreateUnitOfMeasureRequest,
  CreateWorkingDesignationRequest,
  CreateRequiredComplianceDocumentTypeRequest,
  RequiredComplianceDocumentTypeModel,
  UpdateBranchRequest,
  UpdateCityRequest,
  UpdateCountryRequest,
  UpdateDesignationRequest,
  UpdateRegionRequest,
  UpdateStatusCodeRequest,
  UpdateUnitOfMeasureRequest,
  UpdateWorkingDesignationRequest,
  UpdateRequiredComplianceDocumentTypeRequest,
} from '../models/lookup-admin.models';
import { StatusCodeModel } from '../models/lookup.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class LookupAdminService {
  private readonly api = inject(ApiService);

  getCountries(): Observable<CountryModel[]> {
    return this.api
      .get<ApiResponse<CountryModel[]>>(ApiRoutes.LookupAdminCountries)
      .pipe(map((res) => res.data));
  }

  getAllStatusCodes(): Observable<StatusCodeModel[]> {
    return this.api
      .get<ApiResponse<StatusCodeModel[]>>(ApiRoutes.LookupAdminStatusCodes)
      .pipe(map((res) => res.data));
  }

  createRegion(request: CreateRegionRequest): Observable<number> {
    return this.api.post<ApiResponse<number>>(ApiRoutes.LookupAdminRegions, request).pipe(map((res) => res.data));
  }
  updateRegion(request: UpdateRegionRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.LookupAdminRegions, request).pipe(map(() => undefined));
  }
  deleteRegion(id: number): Observable<void> {
    return this.api.delete<ApiResponse<string>>(`${ApiRoutes.LookupAdminRegions}/${id}`).pipe(map(() => undefined));
  }

  createBranch(request: CreateBranchRequest): Observable<number> {
    return this.api.post<ApiResponse<number>>(ApiRoutes.LookupAdminBranches, request).pipe(map((res) => res.data));
  }
  updateBranch(request: UpdateBranchRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.LookupAdminBranches, request).pipe(map(() => undefined));
  }
  deleteBranch(id: number): Observable<void> {
    return this.api.delete<ApiResponse<string>>(`${ApiRoutes.LookupAdminBranches}/${id}`).pipe(map(() => undefined));
  }

  createDesignation(request: CreateDesignationRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.LookupAdminDesignations, request)
      .pipe(map((res) => res.data));
  }
  updateDesignation(request: UpdateDesignationRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.LookupAdminDesignations, request).pipe(map(() => undefined));
  }
  deleteDesignation(id: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.LookupAdminDesignations}/${id}`)
      .pipe(map(() => undefined));
  }

  createWorkingDesignation(request: CreateWorkingDesignationRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.LookupAdminWorkingDesignations, request)
      .pipe(map((res) => res.data));
  }
  updateWorkingDesignation(request: UpdateWorkingDesignationRequest): Observable<void> {
    return this.api
      .put<ApiResponse<string>>(ApiRoutes.LookupAdminWorkingDesignations, request)
      .pipe(map(() => undefined));
  }
  deleteWorkingDesignation(id: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.LookupAdminWorkingDesignations}/${id}`)
      .pipe(map(() => undefined));
  }

  createCountry(request: CreateCountryRequest): Observable<number> {
    return this.api.post<ApiResponse<number>>(ApiRoutes.LookupAdminCountries, request).pipe(map((res) => res.data));
  }
  updateCountry(request: UpdateCountryRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.LookupAdminCountries, request).pipe(map(() => undefined));
  }
  deleteCountry(id: number): Observable<void> {
    return this.api.delete<ApiResponse<string>>(`${ApiRoutes.LookupAdminCountries}/${id}`).pipe(map(() => undefined));
  }

  createCity(request: CreateCityRequest): Observable<number> {
    return this.api.post<ApiResponse<number>>(ApiRoutes.LookupAdminCities, request).pipe(map((res) => res.data));
  }
  updateCity(request: UpdateCityRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.LookupAdminCities, request).pipe(map(() => undefined));
  }
  deleteCity(id: number): Observable<void> {
    return this.api.delete<ApiResponse<string>>(`${ApiRoutes.LookupAdminCities}/${id}`).pipe(map(() => undefined));
  }

  createStatusCode(request: CreateStatusCodeRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.LookupAdminStatusCodes, request)
      .pipe(map((res) => res.data));
  }
  updateStatusCode(request: UpdateStatusCodeRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.LookupAdminStatusCodes, request).pipe(map(() => undefined));
  }
  deleteStatusCode(id: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.LookupAdminStatusCodes}/${id}`)
      .pipe(map(() => undefined));
  }

  createUnitOfMeasure(request: CreateUnitOfMeasureRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.LookupAdminUnitsOfMeasure, request)
      .pipe(map((res) => res.data));
  }
  updateUnitOfMeasure(request: UpdateUnitOfMeasureRequest): Observable<void> {
    return this.api
      .put<ApiResponse<string>>(ApiRoutes.LookupAdminUnitsOfMeasure, request)
      .pipe(map(() => undefined));
  }
  deleteUnitOfMeasure(id: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.LookupAdminUnitsOfMeasure}/${id}`)
      .pipe(map(() => undefined));
  }

  getRequiredComplianceDocumentTypes(): Observable<RequiredComplianceDocumentTypeModel[]> {
    return this.api
      .get<ApiResponse<RequiredComplianceDocumentTypeModel[]>>(ApiRoutes.LookupAdminRequiredComplianceDocumentTypes)
      .pipe(map((res) => res.data));
  }
  createRequiredComplianceDocumentType(request: CreateRequiredComplianceDocumentTypeRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.LookupAdminRequiredComplianceDocumentTypes, request)
      .pipe(map((res) => res.data));
  }
  updateRequiredComplianceDocumentType(request: UpdateRequiredComplianceDocumentTypeRequest): Observable<void> {
    return this.api
      .put<ApiResponse<string>>(ApiRoutes.LookupAdminRequiredComplianceDocumentTypes, request)
      .pipe(map(() => undefined));
  }
  deleteRequiredComplianceDocumentType(id: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.LookupAdminRequiredComplianceDocumentTypes}/${id}`)
      .pipe(map(() => undefined));
  }
}
