import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import {
  CreateCustomerRequest,
  CreateInvoiceRequest,
  CustomerModel,
  InvoiceDetailModel,
  InvoiceFilter,
  InvoiceModel,
  InvoiceSummaryModel,
} from '../models/billing.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class BillingService {
  private readonly api = inject(ApiService);

  getCustomers(activeOnly = true): Observable<CustomerModel[]> {
    return this.api
      .get<ApiResponse<CustomerModel[]>>(ApiRoutes.Customers, { activeOnly })
      .pipe(map((res) => res.data));
  }

  createCustomer(request: CreateCustomerRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.Customers, request)
      .pipe(map((res) => res.data));
  }

  getInvoices(filter: InvoiceFilter): Observable<InvoiceModel[]> {
    return this.api
      .get<ApiResponse<InvoiceModel[]>>(ApiRoutes.Invoices, filter)
      .pipe(map((res) => res.data));
  }

  getInvoiceById(invoiceId: number): Observable<InvoiceDetailModel> {
    return this.api
      .get<ApiResponse<InvoiceDetailModel>>(`${ApiRoutes.Invoices}/${invoiceId}`)
      .pipe(map((res) => res.data));
  }

  createInvoice(request: CreateInvoiceRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.Invoices, request)
      .pipe(map((res) => res.data));
  }

  getInvoiceSummary(fromDate: string, toDate: string, customerId?: number): Observable<InvoiceSummaryModel> {
    return this.api
      .get<ApiResponse<InvoiceSummaryModel>>(ApiRoutes.InvoiceSummary, { fromDate, toDate, customerId })
      .pipe(map((res) => res.data));
  }
}
