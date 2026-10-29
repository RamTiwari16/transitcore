import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import {
  CreateVendorAdvanceRequest,
  CreateVendorBillRequest,
  CreateVendorDeductionRequest,
  CreateVendorPaymentRequest,
  CreateVendorRequest,
  UpdateVendorRequest,
  VendorAdvanceModel,
  VendorAgingReportLineModel,
  VendorBillDetailModel,
  VendorBillModel,
  VendorDeductionModel,
  VendorModel,
  VendorOutstandingBalanceModel,
} from '../models/vendor.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class VendorService {
  private readonly api = inject(ApiService);

  getVendors(activeOnly = true): Observable<VendorModel[]> {
    return this.api
      .get<ApiResponse<VendorModel[]>>(ApiRoutes.Vendors, { activeOnly })
      .pipe(map((res) => res.data));
  }

  getVendorById(vendorId: number): Observable<VendorModel> {
    return this.api
      .get<ApiResponse<VendorModel>>(`${ApiRoutes.Vendors}/${vendorId}`)
      .pipe(map((res) => res.data));
  }

  createVendor(request: CreateVendorRequest): Observable<number> {
    return this.api.post<ApiResponse<number>>(ApiRoutes.Vendors, request).pipe(map((res) => res.data));
  }

  updateVendor(request: UpdateVendorRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.Vendors, request).pipe(map(() => undefined));
  }

  getVendorOutstandingBalance(vendorId: number): Observable<VendorOutstandingBalanceModel> {
    return this.api
      .get<ApiResponse<VendorOutstandingBalanceModel>>(`${ApiRoutes.Vendors}/${vendorId}/outstanding-balance`)
      .pipe(map((res) => res.data));
  }

  // ---- Vendor advances / deductions (per hired trip) ----

  getVendorAdvances(tripId: number): Observable<VendorAdvanceModel[]> {
    return this.api
      .get<ApiResponse<VendorAdvanceModel[]>>(`/api/v1/ops/trips/${tripId}/vendor-advances`)
      .pipe(map((res) => res.data));
  }

  createVendorAdvance(tripId: number, request: CreateVendorAdvanceRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`/api/v1/ops/trips/${tripId}/vendor-advances`, request)
      .pipe(map((res) => res.data));
  }

  deleteVendorAdvance(id: number): Observable<void> {
    return this.api.delete<ApiResponse<string>>(`/api/v1/ops/vendor-advances/${id}`).pipe(map(() => undefined));
  }

  getVendorDeductions(tripId: number): Observable<VendorDeductionModel[]> {
    return this.api
      .get<ApiResponse<VendorDeductionModel[]>>(`/api/v1/ops/trips/${tripId}/vendor-deductions`)
      .pipe(map((res) => res.data));
  }

  createVendorDeduction(tripId: number, request: CreateVendorDeductionRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`/api/v1/ops/trips/${tripId}/vendor-deductions`, request)
      .pipe(map((res) => res.data));
  }

  deleteVendorDeduction(id: number): Observable<void> {
    return this.api.delete<ApiResponse<string>>(`/api/v1/ops/vendor-deductions/${id}`).pipe(map(() => undefined));
  }

  // ---- Vendor bills / payments ----

  getVendorBills(vendorId?: number, statusId?: number): Observable<VendorBillModel[]> {
    return this.api
      .get<ApiResponse<VendorBillModel[]>>(ApiRoutes.VendorBills, { vendorId, statusId })
      .pipe(map((res) => res.data));
  }

  getVendorBillById(vendorBillId: number): Observable<VendorBillDetailModel> {
    return this.api
      .get<ApiResponse<VendorBillDetailModel>>(`${ApiRoutes.VendorBills}/${vendorBillId}`)
      .pipe(map((res) => res.data));
  }

  createVendorBill(tripId: number, request: CreateVendorBillRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`/api/v1/ops/trips/${tripId}/vendor-bill`, request)
      .pipe(map((res) => res.data));
  }

  createVendorPayment(vendorBillId: number, request: CreateVendorPaymentRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.VendorBills}/${vendorBillId}/payments`, request)
      .pipe(map((res) => res.data));
  }

  deleteVendorPayment(paymentId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.VendorPayments}/${paymentId}`)
      .pipe(map(() => undefined));
  }

  getVendorAgingReport(asOfDate?: string): Observable<VendorAgingReportLineModel[]> {
    return this.api
      .get<ApiResponse<VendorAgingReportLineModel[]>>(`${ApiRoutes.VendorBills}/aging-report`, asOfDate ? { asOfDate } : undefined)
      .pipe(map((res) => res.data));
  }
}
