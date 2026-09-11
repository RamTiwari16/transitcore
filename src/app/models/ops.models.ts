export interface RouteModel {
  id: number;
  name: string;
  originCityId: number;
  originCityName: string;
  destinationCityId: number;
  destinationCityName: string;
  distanceKm: number | null;
}

export interface TripFilter {
  fromDate?: string;
  toDate?: string;
  statusId?: number;
  vehicleId?: number;
  driverId?: number;
  routeId?: number;
}

export interface TripModel {
  id: number;
  routeId: number;
  routeName: string;
  vehicleId: number;
  registrationNo: string;
  driverId: number;
  driverName: string;
  scheduledDeparture: string;
  scheduledArrival: string;
  actualDeparture: string | null;
  actualArrival: string | null;
  statusId: number;
  statusName: string;
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
  vehicleId: number;
  driverId: number;
  scheduledDeparture: string;
  scheduledArrival: string;
  statusId: number;
}

export interface UpdateTripStatusRequest {
  tripId: number;
  statusId: number;
  notes?: string;
}

export interface ShipmentFilter {
  customerId?: number;
  statusId?: number;
}

export interface ShipmentModel {
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
}

export interface ShipmentItemModel {
  id: number;
  description: string;
  quantity: number;
  unitOfMeasureId: number;
  unitOfMeasureCode: string;
  weightKg: number | null;
}

export interface ShipmentDetailModel extends ShipmentModel {
  items: ShipmentItemModel[];
}

export interface CreateShipmentItemRequest {
  description: string;
  quantity: number;
  unitOfMeasureId: number;
  weightKg?: number;
}

export interface CreateShipmentRequest {
  customerId: number;
  originCityId: number;
  destinationCityId: number;
  statusId: number;
  shipmentDate: string;
  tripId?: number;
  items: CreateShipmentItemRequest[];
}
