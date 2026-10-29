import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import {
  AgingReportLineModel,
  CreateCustomerRequest,
  CreateInvoiceRequest,
  CreatePaymentRequest,
  CreateRateCardRequest,
  CreateShipmentChargeRequest,
  CustomerModel,
  CustomerOutstandingBalanceModel,
  GenerateInvoiceFromChargesRequest,
  InvoiceDetailModel,
  InvoiceFilter,
  InvoiceModel,
  InvoiceSummaryModel,
  RateCardModel,
  ShipmentChargeModel,
  UninvoicedShipmentModel,
  UpdateCustomerRequest,
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

  getCustomerById(customerId: number): Observable<CustomerModel> {
    return this.api
      .get<ApiResponse<CustomerModel>>(`${ApiRoutes.Customers}/${customerId}`)
      .pipe(map((res) => res.data));
  }

  updateCustomer(request: UpdateCustomerRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.Customers, request).pipe(map(() => undefined));
  }

  getCustomerOutstandingBalance(customerId: number): Observable<CustomerOutstandingBalanceModel> {
    return this.api
      .get<ApiResponse<CustomerOutstandingBalanceModel>>(`${ApiRoutes.Customers}/${customerId}/outstanding-balance`)
      .pipe(map((res) => res.data));
  }

  getUninvoicedShipments(customerId: number, fromDate: string, toDate: string): Observable<UninvoicedShipmentModel[]> {
    return this.api
      .get<ApiResponse<UninvoicedShipmentModel[]>>(`${ApiRoutes.Customers}/${customerId}/uninvoiced-shipments`, {
        fromDate,
        toDate,
      })
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

  getInvoicePdf(invoiceId: number): Observable<Blob> {
    return this.api.getBlob(`${ApiRoutes.Invoices}/${invoiceId}/pdf`);
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

  getAgingReport(asOfDate?: string): Observable<AgingReportLineModel[]> {
    return this.api
      .get<ApiResponse<AgingReportLineModel[]>>(ApiRoutes.InvoiceAgingReport, asOfDate ? { asOfDate } : undefined)
      .pipe(map((res) => res.data));
  }

  // ---- Payments ----

  createPayment(invoiceId: number, request: CreatePaymentRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Invoices}/${invoiceId}/payments`, request)
      .pipe(map((res) => res.data));
  }

  deletePayment(paymentId: number): Observable<void> {
    return this.api.delete<ApiResponse<string>>(`${ApiRoutes.Payments}/${paymentId}`).pipe(map(() => undefined));
  }

  // ---- Rate cards ----

  getRateCards(customerId?: number): Observable<RateCardModel[]> {
    return this.api
      .get<ApiResponse<RateCardModel[]>>(ApiRoutes.RateCards, customerId ? { customerId } : undefined)
      .pipe(map((res) => res.data));
  }

  createRateCard(request: CreateRateCardRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.RateCards, request)
      .pipe(map((res) => res.data));
  }

  deleteRateCard(rateCardId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.RateCards}/${rateCardId}`)
      .pipe(map(() => undefined));
  }

  // ---- Shipment charges (F4) ----

  getShipmentCharges(shipmentId: number): Observable<ShipmentChargeModel[]> {
    return this.api
      .get<ApiResponse<ShipmentChargeModel[]>>(`${ApiRoutes.Shipments}/${shipmentId}/charges`)
      .pipe(map((res) => res.data));
  }

  createShipmentCharge(shipmentId: number, request: CreateShipmentChargeRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Shipments}/${shipmentId}/charges`, request)
      .pipe(map((res) => res.data));
  }

  deleteShipmentCharge(id: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.ShipmentCharges}/${id}`)
      .pipe(map(() => undefined));
  }

  createInvoiceFromCharges(request: GenerateInvoiceFromChargesRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.InvoicesFromCharges, request)
      .pipe(map((res) => res.data));
  }
}
