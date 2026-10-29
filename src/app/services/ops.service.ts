import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import { PagedResult } from '../models/paged-result';
import {
  CheckTripConflictsRequest,
  CreateRouteRequest,
  CreateRouteStopRequest,
  CreateShipmentRequest,
  CreateTripAdvanceRequest,
  CreateTripExpenseRequest,
  CreateTripIncidentRequest,
  CreateTripRequest,
  ProofOfDeliveryModel,
  RouteModel,
  RouteStopModel,
  ShipmentDetailModel,
  ShipmentFilter,
  ShipmentModel,
  ShipmentTrackingModel,
  TripAdvanceModel,
  TripCapacityCheckModel,
  TripConflictModel,
  TripCostSummaryModel,
  TripDetailModel,
  TripDocumentModel,
  TripExpenseModel,
  TripFilter,
  TripIncidentModel,
  TripModel,
  TripStopShipmentModel,
  CreateTripStopShipmentRequest,
  TripStopVisitModel,
  UpsertTripStopVisitRequest,
  UpdateTripKmRequest,
  ConsignmentNoteDetailModel,
  CancelConsignmentNoteRequest,
  ShipmentItemDeliveryLineModel,
  UpdateShipmentItemDeliveryRequest,
  TripDispatchComplianceCheckModel,
  UpdateConsignmentNoteEwayBillRequest,
  ExpiringEwayBillModel,
  UpdateRouteRequest,
  UpdateShipmentRequest,
  UpdateTripRequest,
  UpdateTripStatusRequest,
} from '../models/ops.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class OpsService {
  private readonly api = inject(ApiService);

  getRoutes(): Observable<RouteModel[]> {
    return this.api.get<ApiResponse<RouteModel[]>>(ApiRoutes.Routes).pipe(map((res) => res.data));
  }

  createRoute(request: CreateRouteRequest): Observable<number> {
    return this.api.post<ApiResponse<number>>(ApiRoutes.Routes, request).pipe(map((res) => res.data));
  }

  getRouteById(routeId: number): Observable<RouteModel> {
    return this.api
      .get<ApiResponse<RouteModel>>(`${ApiRoutes.Routes}/${routeId}`)
      .pipe(map((res) => res.data));
  }

  updateRoute(request: UpdateRouteRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.Routes, request).pipe(map(() => undefined));
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

  updateTrip(request: UpdateTripRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.Trips, request).pipe(map(() => undefined));
  }

  checkTripConflicts(request: CheckTripConflictsRequest): Observable<TripConflictModel[]> {
    return this.api
      .post<ApiResponse<TripConflictModel[]>>(ApiRoutes.TripConflicts, request)
      .pipe(map((res) => res.data));
  }

  getTripCapacityCheck(tripId: number): Observable<TripCapacityCheckModel> {
    return this.api
      .get<ApiResponse<TripCapacityCheckModel>>(`${ApiRoutes.Trips}/${tripId}/capacity-check`)
      .pipe(map((res) => res.data));
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

  updateShipment(request: UpdateShipmentRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.Shipments, request).pipe(map(() => undefined));
  }

  // ---- Trip expenses ----

  getTripExpenses(tripId: number): Observable<TripExpenseModel[]> {
    return this.api
      .get<ApiResponse<TripExpenseModel[]>>(`${ApiRoutes.Trips}/${tripId}/expenses`)
      .pipe(map((res) => res.data));
  }

  createTripExpense(tripId: number, request: CreateTripExpenseRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Trips}/${tripId}/expenses`, request)
      .pipe(map((res) => res.data));
  }

  deleteTripExpense(expenseId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.TripExpenses}/${expenseId}`)
      .pipe(map(() => undefined));
  }

  // ---- Trip advances ----

  getTripAdvances(tripId: number): Observable<TripAdvanceModel[]> {
    return this.api
      .get<ApiResponse<TripAdvanceModel[]>>(`${ApiRoutes.Trips}/${tripId}/advances`)
      .pipe(map((res) => res.data));
  }

  createTripAdvance(tripId: number, request: CreateTripAdvanceRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Trips}/${tripId}/advances`, request)
      .pipe(map((res) => res.data));
  }

  deleteTripAdvance(advanceId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.TripAdvances}/${advanceId}`)
      .pipe(map(() => undefined));
  }

  getTripCostSummary(tripId: number): Observable<TripCostSummaryModel> {
    return this.api
      .get<ApiResponse<TripCostSummaryModel>>(`${ApiRoutes.Trips}/${tripId}/cost-summary`)
      .pipe(map((res) => res.data));
  }

  // ---- Proof of delivery ----

  getProofOfDelivery(tripId: number): Observable<ProofOfDeliveryModel | null> {
    return this.api
      .get<ApiResponse<ProofOfDeliveryModel | null>>(`${ApiRoutes.Trips}/${tripId}/proof-of-delivery`)
      .pipe(map((res) => res.data));
  }

  createProofOfDelivery(tripId: number, formData: FormData): Observable<number> {
    return this.api
      .postFormData<ApiResponse<number>>(`${ApiRoutes.Trips}/${tripId}/proof-of-delivery`, formData)
      .pipe(map((res) => res.data));
  }

  // ---- Trip documents ----

  getTripDocuments(tripId: number): Observable<TripDocumentModel[]> {
    return this.api
      .get<ApiResponse<TripDocumentModel[]>>(`${ApiRoutes.Trips}/${tripId}/documents`)
      .pipe(map((res) => res.data));
  }

  createTripDocument(tripId: number, formData: FormData): Observable<number> {
    return this.api
      .postFormData<ApiResponse<number>>(`${ApiRoutes.Trips}/${tripId}/documents`, formData)
      .pipe(map((res) => res.data));
  }

  deleteTripDocument(documentId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.TripDocuments}/${documentId}`)
      .pipe(map(() => undefined));
  }

  // ---- Trip incidents ----

  getTripIncidents(tripId: number): Observable<TripIncidentModel[]> {
    return this.api
      .get<ApiResponse<TripIncidentModel[]>>(`${ApiRoutes.Trips}/${tripId}/incidents`)
      .pipe(map((res) => res.data));
  }

  createTripIncident(tripId: number, request: CreateTripIncidentRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Trips}/${tripId}/incidents`, request)
      .pipe(map((res) => res.data));
  }

  deleteTripIncident(incidentId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.TripIncidents}/${incidentId}`)
      .pipe(map(() => undefined));
  }

  // ---- Route stops (multi-stop legs) ----

  getRouteStops(routeId: number): Observable<RouteStopModel[]> {
    return this.api
      .get<ApiResponse<RouteStopModel[]>>(`${ApiRoutes.Routes}/${routeId}/stops`)
      .pipe(map((res) => res.data));
  }

  createRouteStop(routeId: number, request: CreateRouteStopRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(`${ApiRoutes.Routes}/${routeId}/stops`, request)
      .pipe(map((res) => res.data));
  }

  deleteRouteStop(stopId: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.RouteStops}/${stopId}`)
      .pipe(map(() => undefined));
  }

  // ---- Trip stop shipments (load/unload events) ----

  getTripStopShipments(tripId: number): Observable<TripStopShipmentModel[]> {
    return this.api
      .get<ApiResponse<TripStopShipmentModel[]>>(`${ApiRoutes.Trips}/${tripId}/stop-shipments`)
      .pipe(map((res) => res.data));
  }

  createTripStopShipment(tripId: number, request: CreateTripStopShipmentRequest): Observable<void> {
    return this.api
      .post<ApiResponse<string>>(`${ApiRoutes.Trips}/${tripId}/stop-shipments`, request)
      .pipe(map(() => undefined));
  }

  deleteTripStopShipment(id: number): Observable<void> {
    return this.api
      .delete<ApiResponse<string>>(`${ApiRoutes.TripStopShipments}/${id}`)
      .pipe(map(() => undefined));
  }

  updateTripKm(tripId: number, request: UpdateTripKmRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(`${ApiRoutes.Trips}/${tripId}/km`, request).pipe(map(() => undefined));
  }

  getTripDispatchCompliance(tripId: number): Observable<TripDispatchComplianceCheckModel[]> {
    return this.api
      .get<ApiResponse<TripDispatchComplianceCheckModel[]>>(`${ApiRoutes.Trips}/${tripId}/dispatch-compliance`)
      .pipe(map((res) => res.data));
  }

  updateConsignmentNoteEwayBill(shipmentId: number, request: UpdateConsignmentNoteEwayBillRequest): Observable<void> {
    return this.api
      .put<ApiResponse<string>>(`${ApiRoutes.Shipments}/${shipmentId}/consignment-note/eway-bill`, request)
      .pipe(map(() => undefined));
  }

  getExpiringEwayBills(daysAhead = 3): Observable<ExpiringEwayBillModel[]> {
    return this.api
      .get<ApiResponse<ExpiringEwayBillModel[]>>('/api/v1/ops/consignment-notes/expiring-eway-bills', { daysAhead })
      .pipe(map((res) => res.data));
  }

  // ---- Trip stop visits (detention tracking) ----

  getTripStopVisits(tripId: number): Observable<TripStopVisitModel[]> {
    return this.api
      .get<ApiResponse<TripStopVisitModel[]>>(`${ApiRoutes.Trips}/${tripId}/stop-visits`)
      .pipe(map((res) => res.data));
  }

  upsertTripStopVisit(tripId: number, request: UpsertTripStopVisitRequest): Observable<TripStopVisitModel> {
    return this.api
      .post<ApiResponse<TripStopVisitModel>>(`${ApiRoutes.Trips}/${tripId}/stop-visits`, request)
      .pipe(map((res) => res.data));
  }

  // ---- Consignment notes ----

  getConsignmentNoteByShipmentId(shipmentId: number): Observable<ConsignmentNoteDetailModel> {
    return this.api
      .get<ApiResponse<ConsignmentNoteDetailModel>>(`${ApiRoutes.Shipments}/${shipmentId}/consignment-note`)
      .pipe(map((res) => res.data));
  }

  getConsignmentNotePdf(shipmentId: number): Observable<Blob> {
    return this.api.getBlob(`${ApiRoutes.Shipments}/${shipmentId}/consignment-note/pdf`);
  }

  cancelConsignmentNote(shipmentId: number, request: CancelConsignmentNoteRequest): Observable<void> {
    return this.api
      .post<ApiResponse<string>>(`${ApiRoutes.Shipments}/${shipmentId}/consignment-note/cancel`, request)
      .pipe(map(() => undefined));
  }

  // ---- Shipment item delivery reconciliation (F7) ----

  getShipmentItemDeliveries(shipmentId: number): Observable<ShipmentItemDeliveryLineModel[]> {
    return this.api
      .get<ApiResponse<ShipmentItemDeliveryLineModel[]>>(`${ApiRoutes.Shipments}/${shipmentId}/item-deliveries`)
      .pipe(map((res) => res.data));
  }

  createShipmentItemDelivery(shipmentItemId: number, formData: FormData): Observable<number> {
    return this.api
      .postFormData<ApiResponse<number>>(`/api/v1/ops/shipment-items/${shipmentItemId}/delivery`, formData)
      .pipe(map((res) => res.data));
  }

  updateShipmentItemDelivery(deliveryId: number, request: UpdateShipmentItemDeliveryRequest): Observable<void> {
    return this.api
      .put<ApiResponse<string>>(`/api/v1/ops/shipment-item-deliveries/${deliveryId}`, request)
      .pipe(map(() => undefined));
  }

  addShipmentItemDeliveryPhoto(deliveryId: number, formData: FormData): Observable<number> {
    return this.api
      .postFormData<ApiResponse<number>>(`/api/v1/ops/shipment-item-deliveries/${deliveryId}/photos`, formData)
      .pipe(map((res) => res.data));
  }

  // ---- Public shipment tracking ----

  trackShipment(trackingNo: string): Observable<ShipmentTrackingModel> {
    return this.api
      .get<ApiResponse<ShipmentTrackingModel>>(`${ApiRoutes.PublicTrack}/${trackingNo}`)
      .pipe(map((res) => res.data));
  }
}
