export interface RevenueByPeriodModel {
  periodLabel: string;
  totalInvoiced: number;
  totalCollected: number;
}

export interface DriverSettlementSummaryModel {
  driverId: number;
  fullName: string;
  totalAdvances: number;
  totalExpenses: number;
  balance: number;
}

export interface FleetUtilisationTrendModel {
  periodLabel: string;
  utilisationPercent: number;
}

export interface ShipmentVolumeTrendModel {
  periodLabel: string;
  shipmentCount: number;
}

// Own trips only - a Hired trip has no fleet vehicle to attribute empty-km to.
export interface EmptyKmReportModel {
  vehicleId: number;
  registrationNo: string;
  totalLoadedKm: number;
  totalEmptyKm: number;
  totalKm: number;
  emptyKmPercent: number;
  tripCount: number;
}

export interface VehicleAvailabilityModel {
  vehicleId: number;
  registrationNo: string;
  vehicleTypeName: string;
  isAvailableNow: boolean;
  expectedFreeAt: string | null;
  currentTripRoute: string | null;
}
