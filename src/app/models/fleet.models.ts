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

export interface FleetUtilisationModel {
  vehicleId: number;
  registrationNo: string;
  vehicleTypeName: string;
  totalTrips: number;
  scheduledHours: number;
  utilisationPercent: number;
}
