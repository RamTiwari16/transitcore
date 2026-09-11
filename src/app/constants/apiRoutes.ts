export const ApiRoutes = {
  Login: '/api/v1/auth/login',
  BulkUpload: '/api/v1/vehicleorder/bulk-upload',
  GetByDateRange: '/api/v1/vehicleorder/get-by-date-range',

  Regions: '/api/v1/lookup/regions',
  Branches: '/api/v1/lookup/branches',
  Designations: '/api/v1/lookup/designations',
  WorkingDesignations: '/api/v1/lookup/working-designations',
  StatusCodes: '/api/v1/lookup/status-codes',

  VehicleTypes: '/api/v1/fleet/vehicle-types',
  Vehicles: '/api/v1/fleet/vehicles',
  Drivers: '/api/v1/fleet/drivers',
  FleetUtilisation: '/api/v1/fleet/utilisation',

  Routes: '/api/v1/ops/routes',
  Trips: '/api/v1/ops/trips',
  TripStatus: '/api/v1/ops/trips/status',

  Customers: '/api/v1/billing/customers',
  Invoices: '/api/v1/billing/invoices',
  InvoiceSummary: '/api/v1/billing/invoices/summary',
};
