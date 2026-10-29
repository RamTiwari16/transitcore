export interface VehicleTypeModel {
  id: number;
  name: string;
  description: string | null;
  capacityKg: number;
}

export interface VehicleModel {
  id: number;
  registrationNo: string;
  vehicleTypeId: number;
  vehicleTypeName: string;
  make: string | null;
  model: string | null;
  manufactureYear: number | null;
  capacityKg: number;
  statusId: number;
  statusName: string;
}

export interface CreateVehicleRequest {
  registrationNo: string;
  vehicleTypeId: number;
  make?: string;
  model?: string;
  manufactureYear?: number;
  capacityKg: number;
  statusId: number;
}

export interface UpdateVehicleRequest extends CreateVehicleRequest {
  vehicleId: number;
}

export interface DriverModel {
  id: number;
  fullName: string;
  phoneNo: string | null;
  email: string | null;
  hireDate: string | null;
  statusId: number;
  statusName: string;
}

export interface CreateDriverRequest {
  fullName: string;
  phoneNo?: string;
  email?: string;
  dateOfBirth?: string;
  hireDate?: string;
  statusId: number;
}

export interface DriverDetailModel extends DriverModel {
  dateOfBirth: string | null;
}

export interface UpdateDriverRequest {
  driverId: number;
  fullName: string;
  phoneNo?: string;
  email?: string;
  dateOfBirth?: string;
  hireDate?: string;
  statusId: number;
}

// ---- Vehicle documents ----

export interface VehicleDocumentModel {
  id: number;
  vehicleId: number;
  documentType: string;
  documentNo: string | null;
  issuedDate: string | null;
  expiryDate: string | null;
}

export interface CreateVehicleDocumentRequest {
  documentType: string;
  documentNo?: string;
  issuedDate?: string;
  expiryDate?: string;
}

export interface ExpiringVehicleDocumentModel {
  id: number;
  vehicleId: number;
  registrationNo: string;
  documentType: string;
  documentNo: string | null;
  expiryDate: string;
}

// ---- Maintenance records ----

export interface MaintenanceRecordModel {
  id: number;
  vehicleId: number;
  serviceDate: string;
  description: string | null;
  cost: number;
  odometerKm: number | null;
  performedBy: string | null;
}

export interface CreateMaintenanceRecordRequest {
  serviceDate: string;
  description?: string;
  cost: number;
  odometerKm?: number;
  performedBy?: string;
}

// ---- Fuel logs ----

export interface FuelLogModel {
  id: number;
  vehicleId: number;
  fuelDate: string;
  liters: number;
  cost: number;
  odometerKm: number | null;
  kmPerLiter: number | null;
}

export interface CreateFuelLogRequest {
  fuelDate: string;
  liters: number;
  cost: number;
  odometerKm?: number;
}

// ---- Driver licences / medical certificates ----

export interface DriverLicenseModel {
  id: number;
  driverId: number;
  licenseNo: string;
  licenseType: string | null;
  issuedDate: string | null;
  expiryDate: string | null;
}

export interface CreateDriverLicenseRequest {
  licenseNo: string;
  licenseType?: string;
  issuedDate?: string;
  expiryDate?: string;
}

export interface ExpiringDriverLicenseModel {
  id: number;
  driverId: number;
  driverName: string;
  licenseType: string | null;
  licenseNo: string;
  expiryDate: string;
}

// ---- Driver performance ----

export interface DriverPerformanceModel {
  driverId: number;
  totalTrips: number;
  completedTrips: number;
  onTimeTrips: number;
  delayedTrips: number;
  totalDistanceKm: number;
  onTimePercent: number | null;
}

// Fleet-wide advances vs expenses across every trip a driver has, not just
// one (compare DriverPerformanceModel above and TripCostSummaryModel in
// ops.models.ts, the single-trip version).
export interface DriverSettlementModel {
  driverId: number;
  totalAdvances: number;
  totalExpenses: number;
  tripsWithActivity: number;
  balance: number;
}

export interface FleetUtilisationModel {
  vehicleId: number;
  registrationNo: string;
  vehicleTypeName: string;
  totalTrips: number;
  scheduledHours: number;
  utilisationPercent: number;
}
