export interface RouteModel {
  id: number;
  name: string;
  originCityId: number;
  originCityName: string;
  destinationCityId: number;
  destinationCityName: string;
  distanceKm: number | null;
}

export interface CreateRouteRequest {
  name: string;
  originCityId: number;
  destinationCityId: number;
  distanceKm?: number;
}

export interface UpdateRouteRequest {
  routeId: number;
  name: string;
  originCityId: number;
  destinationCityId: number;
  distanceKm?: number;
}

export interface TripFilter {
  fromDate?: string;
  toDate?: string;
  statusId?: number;
  vehicleId?: number;
  driverId?: number;
  routeId?: number;
}

// vehicleId/registrationNo/driverId/driverName are null for a Hired trip -
// see ownershipType/vendorId/hiredVehicleNo etc. instead.
export interface TripModel {
  id: number;
  routeId: number;
  routeName: string;
  vehicleId: number | null;
  registrationNo: string | null;
  driverId: number | null;
  driverName: string | null;
  scheduledDeparture: string;
  scheduledArrival: string;
  actualDeparture: string | null;
  actualArrival: string | null;
  statusId: number;
  statusName: string;
  ownershipType: string;
  vendorId: number | null;
  vendorName: string | null;
  hiredVehicleNo: string | null;
  hiredDriverName: string | null;
  hiredDriverPhone: string | null;
  vendorFreightAmount: number | null;
  loadedKm: number | null;
  emptyKm: number | null;
}

// Deliberately separate from the general trip edit form - actual run km is
// dispatch-workflow data entered once a trip is done.
export interface UpdateTripKmRequest {
  loadedKm: number;
  emptyKm: number;
}

export interface TripStatusHistoryModel {
  id: number;
  statusId: number;
  statusName: string;
  changedAt: string;
  notes: string | null;
}

export interface TripDetailModel extends TripModel {
  statusHistory: TripStatusHistoryModel[];
}

export interface CreateTripRequest {
  routeId: number;
  scheduledDeparture: string;
  scheduledArrival: string;
  statusId: number;
  ownershipType: string;
  vehicleId?: number;
  driverId?: number;
  vendorId?: number;
  hiredVehicleNo?: string;
  hiredDriverName?: string;
  hiredDriverPhone?: string;
  vendorFreightAmount?: number;
}

export interface UpdateTripStatusRequest {
  tripId: number;
  statusId: number;
  notes?: string;
}

// Header fields only - status transitions go through UpdateTripStatusRequest
// instead, which is audited via the trip's status history.
export interface UpdateTripRequest {
  tripId: number;
  routeId: number;
  scheduledDeparture: string;
  scheduledArrival: string;
  ownershipType: string;
  vehicleId?: number;
  driverId?: number;
  vendorId?: number;
  hiredVehicleNo?: string;
  hiredDriverName?: string;
  hiredDriverPhone?: string;
  vendorFreightAmount?: number;
}

export interface ShipmentFilter {
  customerId?: number;
  statusId?: number;
}

export interface ShipmentParties {
  consignorCustomerId: number | null;
  consignorName: string | null;
  consignorAddress: string | null;
  consignorPhone: string | null;
  consigneeCustomerId: number | null;
  consigneeName: string | null;
  consigneeAddress: string | null;
  consigneePhone: string | null;
}

export interface ShipmentModel extends ShipmentParties {
  id: number;
  tripId: number | null;
  customerId: number;
  customerName: string;
  originCityId: number;
  originCityName: string;
  destinationCityId: number;
  destinationCityName: string;
  statusId: number;
  statusName: string;
  shipmentDate: string;
  trackingNo: string | null;
  freightPaymentTypeId: number;
  freightPaymentTypeName: string;
  consignorCustomerName: string | null;
  consigneeCustomerName: string | null;
  cnNumber: string | null;
}

export interface ShipmentItemModel {
  id: number;
  description: string;
  quantity: number;
  unitOfMeasureId: number;
  unitOfMeasureCode: string;
  weightKg: number | null;
  volumeCbm: number | null;
}

export interface ShipmentDetailModel extends ShipmentModel {
  items: ShipmentItemModel[];
}

export interface CreateShipmentItemRequest {
  description: string;
  quantity: number;
  unitOfMeasureId: number;
  weightKg?: number;
  volumeCbm?: number;
}

export interface CreateShipmentRequest {
  customerId: number;
  originCityId: number;
  destinationCityId: number;
  statusId: number;
  shipmentDate: string;
  tripId?: number;
  freightPaymentTypeId: number;
  items: CreateShipmentItemRequest[];
}

// Header fields only - line items aren't editable through this request yet.
// The API overwrites every party field, so edits must send the loaded values back.
export interface UpdateShipmentRequest extends ShipmentParties {
  shipmentId: number;
  customerId: number;
  originCityId: number;
  destinationCityId: number;
  statusId: number;
  shipmentDate: string;
  freightPaymentTypeId: number;
}

// ---- Trip expenses / advances (cost tracking, not full revenue P&L) ----

export interface TripExpenseModel {
  id: number;
  tripId: number;
  expenseType: string;
  amount: number;
  expenseDate: string;
  notes: string | null;
}

export interface CreateTripExpenseRequest {
  expenseType: string;
  amount: number;
  expenseDate: string;
  notes?: string;
}

export interface TripAdvanceModel {
  id: number;
  tripId: number;
  amount: number;
  advanceDate: string;
  notes: string | null;
}

export interface CreateTripAdvanceRequest {
  amount: number;
  advanceDate: string;
  notes?: string;
}

export interface TripCostSummaryModel {
  tripId: number;
  totalExpenses: number;
  totalAdvances: number;
  balance: number;
  // Sum of every ShipmentCharge for shipments carried on this trip.
  customerChargesTotal: number;
  // Agreed vendor freight for a Hired trip; null for an Own trip.
  vendorFreightAmount: number | null;
  profit: number;
}

// ---- Proof of delivery ----

export interface ProofOfDeliveryPhotoModel {
  id: number;
  filePath: string;
}

export interface ProofOfDeliveryModel {
  id: number;
  tripId: number;
  receiverName: string;
  receiverPhone: string | null;
  deliveredAt: string;
  notes: string | null;
  signatureFilePath: string | null;
  photos: ProofOfDeliveryPhotoModel[];
}

// ---- Trip documents ----

export interface TripDocumentModel {
  id: number;
  tripId: number;
  documentType: string;
  fileName: string;
  filePath: string;
  uploadedAt: string;
}

// ---- Trip incidents / delay reports ----

export interface TripIncidentModel {
  id: number;
  tripId: number;
  incidentType: string;
  description: string;
  reportedAt: string;
  reportedBy: string | null;
}

export interface CreateTripIncidentRequest {
  incidentType: string;
  description: string;
}

// ---- Multi-stop route legs ----

export interface RouteStopModel {
  id: number;
  routeId: number;
  cityId: number;
  cityName: string;
  stopOrder: number;
  plannedArrival: string | null;
}

export interface CreateRouteStopRequest {
  cityId: number;
  stopOrder: number;
  plannedArrival?: string;
}

// ---- Trip capacity check ----
// All fields nullable - a Hired trip has no fleet vehicle to check capacity
// against, so the API returns nulls rather than zeros for it.

export interface TripCapacityCheckModel {
  tripId: number;
  vehicleCapacityKg: number | null;
  vehicleCapacityCbm: number | null;
  assignedWeightKg: number | null;
  assignedVolumeCbm: number | null;
  isOverCapacity: boolean;
  isOverVolumeCapacity: boolean;
}

// ---- Trip stop shipments (load/unload events) ----
// Action: 'Load' | 'Unload'. StopType: 'Origin' | 'IntermediateStop' | 'Destination'.
// routeStopId only applies (and is required) for 'IntermediateStop' - a
// trip's own origin/destination act as implicit stops without needing a
// RouteStops row of their own.

export interface TripStopShipmentModel {
  id: number;
  tripId: number;
  shipmentId: number;
  trackingNo: string | null;
  customerId: number;
  customerName: string;
  action: string;
  stopType: string;
  routeStopId: number | null;
  stopCityName: string;
  sortKey: number;
  createdAt: string;
  createdBy: string | null;
}

export interface CreateTripStopShipmentRequest {
  shipmentId: number;
  action: string;
  stopType: string;
  routeStopId?: number;
}

// ---- Trip stop visits (detention tracking) ----
// One row per (trip, stop) - upsert by StopType (+ routeStopId for
// IntermediateStop), not a separate insert/update pair. DwellHours is
// computed server-side from arrivedAt/departedAt.

export interface TripStopVisitModel {
  id: number;
  tripId: number;
  stopType: string;
  routeStopId: number | null;
  stopCityName: string;
  arrivedAt: string | null;
  departedAt: string | null;
  dwellHours: number | null;
}

export interface UpsertTripStopVisitRequest {
  stopType: string;
  routeStopId?: number;
  arrivedAt?: string;
  departedAt?: string;
}

// ---- Consignment notes ----

export interface ConsignmentNoteModel {
  id: number;
  shipmentId: number;
  cnNumber: string;
  branchId: number;
  branchName: string;
  cnDate: string;
  packages: number | null;
  actualWeightKg: number | null;
  chargedWeightKg: number | null;
  declaredValue: number | null;
  freightAmount: number | null;
  remarks: string | null;
  statusId: number;
  statusName: string;
  cancelReason: string | null;
  cancelledAt: string | null;
  cancelledBy: string | null;
  ewayBillNo: string | null;
  ewayBillGeneratedDate: string | null;
  ewayBillValidUntil: string | null;
  trackingNo: string | null;
  originCityId: number;
  originCityName: string;
  destinationCityId: number;
  destinationCityName: string;
  shipmentDate: string;
  freightPaymentTypeId: number;
  freightPaymentTypeName: string;
  billingPartyCustomerId: number;
  billingPartyName: string;
  consignorCustomerId: number | null;
  consignorCustomerName: string | null;
  consignorName: string | null;
  consignorAddress: string | null;
  consignorPhone: string | null;
  consigneeCustomerId: number | null;
  consigneeCustomerName: string | null;
  consigneeName: string | null;
  consigneeAddress: string | null;
  consigneePhone: string | null;
  tripId: number | null;
  vehicleId: number | null;
  vehicleRegistrationNo: string | null;
  driverId: number | null;
  driverName: string | null;
}

export interface ConsignmentNoteDetailModel extends ConsignmentNoteModel {
  items: ShipmentItemModel[];
}

export interface CancelConsignmentNoteRequest {
  cancelReason: string;
}

// ---- Shipment item delivery reconciliation (F7) ----

export interface ShipmentItemDeliveryPhotoModel {
  id: number;
  filePath: string;
}

export interface ShipmentItemDeliveryModel {
  deliveryId: number;
  deliveredQty: number;
  shortQty: number;
  damagedQty: number;
  remarks: string | null;
  recordedAt: string;
  photos: ShipmentItemDeliveryPhotoModel[];
}

// One row per item on the shipment - delivery is null until reconciliation
// has actually been recorded for that item.
export interface ShipmentItemDeliveryLineModel {
  shipmentItemId: number;
  description: string;
  quantity: number;
  unitOfMeasureCode: string;
  weightKg: number | null;
  volumeCbm: number | null;
  delivery: ShipmentItemDeliveryModel | null;
}

export interface UpdateShipmentItemDeliveryRequest {
  deliveredQty: number;
  shortQty: number;
  damagedQty: number;
  remarks?: string;
}

// ---- Dispatch compliance check (F8) ----
// Own trips only - a Hired trip has no fleet vehicle/driver to check, so it
// simply returns an empty list. Status is 'Missing' | 'Expired' | 'Valid' -
// purely informational, nothing here blocks a status change.

export interface TripDispatchComplianceCheckModel {
  checkType: string;
  label: string;
  status: string;
  expiryDate: string | null;
}

// ---- E-way bill (F8) ----

export interface UpdateConsignmentNoteEwayBillRequest {
  ewayBillNo: string;
  ewayBillGeneratedDate: string;
  ewayBillValidUntil: string;
}

export interface ExpiringEwayBillModel {
  consignmentNoteId: number;
  shipmentId: number;
  cnNumber: string;
  trackingNo: string | null;
  ewayBillNo: string;
  ewayBillValidUntil: string;
  daysUntilExpiry: number;
}

// ---- Dispatch conflict check ----

// Both null for a Hired trip being checked - it has no fleet vehicle/driver
// to conflict against, so conflict-checking simply finds nothing.
export interface CheckTripConflictsRequest {
  driverId?: number;
  vehicleId?: number;
  scheduledDeparture: string;
  scheduledArrival: string;
  excludeTripId?: number;
}

export interface TripConflictModel {
  id: number;
  routeId: number;
  routeName: string;
  vehicleId: number | null;
  registrationNo: string | null;
  driverId: number | null;
  driverName: string | null;
  scheduledDeparture: string;
  scheduledArrival: string;
  statusId: number;
  statusName: string;
  isDriverConflict: boolean;
  isVehicleConflict: boolean;
}

// ---- Public shipment tracking ----

export interface ShipmentTrackingModel {
  trackingNo: string;
  shipmentDate: string;
  originCityName: string;
  destinationCityName: string;
  statusName: string;
  scheduledDeparture: string | null;
  scheduledArrival: string | null;
  actualDeparture: string | null;
  actualArrival: string | null;
  tripStatusName: string | null;
}
