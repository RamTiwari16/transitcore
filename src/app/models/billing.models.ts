export interface CustomerModel {
  id: number;
  code: string;
  name: string;
  isActive: boolean;
  creditLimit: number | null;
}

export interface CreateCustomerRequest {
  code: string;
  name: string;
  creditLimit?: number;
}

// Code is the immutable natural key once created - not accepted here.
export interface UpdateCustomerRequest {
  customerId: number;
  name: string;
  isActive: boolean;
  creditLimit?: number;
}

export interface CustomerOutstandingBalanceModel {
  customerId: number;
  outstandingBalance: number;
}

export interface InvoiceFilter {
  customerId?: number;
  statusId?: number;
}

export interface InvoiceModel {
  id: number;
  invoiceNo: string;
  customerId: number;
  customerName: string;
  invoiceDate: string;
  dueDate: string;
  subtotal: number;
  discountAmount: number;
  taxAmount: number;
  totalAmount: number;
  statusId: number;
  statusName: string;
  paidAmount: number;
}

export interface InvoiceLineModel {
  id: number;
  shipmentId: number | null;
  description: string;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
}

export interface PaymentModel {
  id: number;
  paymentDate: string;
  amount: number;
  method: string;
  referenceNo: string | null;
}

export interface InvoiceDetailModel extends InvoiceModel {
  lines: InvoiceLineModel[];
  payments: PaymentModel[];
}

export interface CreateInvoiceLineRequest {
  shipmentId?: number;
  description: string;
  quantity: number;
  unitPrice: number;
}

export interface CreateInvoiceRequest {
  invoiceNo: string;
  customerId: number;
  invoiceDate: string;
  dueDate: string;
  discountAmount: number;
  taxAmount: number;
  statusId: number;
  lines: CreateInvoiceLineRequest[];
}

export interface InvoiceSummaryModel {
  invoiceCount: number;
  totalInvoiced: number;
  totalPaid: number;
  totalOutstanding: number;
}

export interface CreatePaymentRequest {
  paymentDate: string;
  amount: number;
  method: string;
  referenceNo?: string;
}

export interface AgingReportLineModel {
  id: number;
  invoiceNo: string;
  customerId: number;
  customerName: string;
  invoiceDate: string;
  dueDate: string;
  outstandingAmount: number;
  daysOverdue: number;
}

// ---- Rate cards ----

// Basis picks which rate field below FreightCalculator actually uses -
// 'PerTrip' | 'PerTon' | 'PerKm' | 'PerPackage'. ratePerKm doubles as the
// active rate when basis is 'PerKm'; ratePerKg is legacy and never used by
// the calculator (kept only because existing rows may still have it set).
export interface RateCardModel {
  id: number;
  customerId: number | null;
  customerName: string | null;
  originCityId: number | null;
  originCityName: string | null;
  destinationCityId: number | null;
  destinationCityName: string | null;
  ratePerKg: number;
  ratePerKm: number;
  basis: string;
  ratePerTrip: number | null;
  ratePerTon: number | null;
  ratePerPackage: number | null;
  minimumChargeableWeightKg: number | null;
  loadingRatePerEvent: number | null;
  unloadingRatePerEvent: number | null;
  detentionFreeHours: number | null;
  detentionRatePerHour: number | null;
  haltingRatePerDay: number | null;
  effectiveFrom: string;
  effectiveTo: string | null;
}

export interface CreateRateCardRequest {
  customerId?: number;
  originCityId?: number;
  destinationCityId?: number;
  ratePerKg: number;
  ratePerKm: number;
  basis: string;
  ratePerTrip?: number;
  ratePerTon?: number;
  ratePerPackage?: number;
  minimumChargeableWeightKg?: number;
  loadingRatePerEvent?: number;
  unloadingRatePerEvent?: number;
  detentionFreeHours?: number;
  detentionRatePerHour?: number;
  haltingRatePerDay?: number;
  effectiveFrom: string;
  effectiveTo?: string;
}

// ---- Generate invoice from shipments ----

export interface UninvoicedShipmentModel {
  id: number;
  trackingNo: string | null;
  originCityId: number;
  originCityName: string;
  destinationCityId: number;
  destinationCityName: string;
  shipmentDate: string;
  totalWeightKg: number;
  routeDistanceKm: number | null;
  estimatedAmount: number | null;
}

// ---- Shipment charges (F4) ----
// ChargeType is freeform ("Freight", "Loading", "Unloading", "Detention",
// "Halting", ...) - matches whatever FreightCalculator/staff labelled it.

export interface ShipmentChargeModel {
  id: number;
  shipmentId: number;
  chargeType: string;
  amount: number;
  description: string | null;
  isOverridden: boolean;
  overrideReason: string | null;
  isInvoiced: boolean;
  createdAt: string;
  createdBy: string | null;
}

export interface CreateShipmentChargeRequest {
  chargeType: string;
  amount: number;
  description?: string;
  isOverridden: boolean;
  overrideReason?: string;
}

export interface GenerateInvoiceFromChargesRequest {
  invoiceNo: string;
  customerId: number;
  invoiceDate: string;
  dueDate: string;
  discountAmount: number;
  taxAmount: number;
  statusId: number;
  shipmentChargeIds: number[];
}
