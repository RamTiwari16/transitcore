export interface VendorModel {
  id: number;
  code: string;
  name: string;
  contactName: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  address: string | null;
  bankAccountNo: string | null;
  bankIfscCode: string | null;
  panNo: string | null;
  gstinNo: string | null;
  isActive: boolean;
}

export interface CreateVendorRequest {
  code: string;
  name: string;
  contactName?: string;
  contactPhone?: string;
  contactEmail?: string;
  address?: string;
  bankAccountNo?: string;
  bankIfscCode?: string;
  panNo?: string;
  gstinNo?: string;
}

export interface UpdateVendorRequest {
  vendorId: number;
  name: string;
  contactName?: string;
  contactPhone?: string;
  contactEmail?: string;
  address?: string;
  bankAccountNo?: string;
  bankIfscCode?: string;
  panNo?: string;
  gstinNo?: string;
  isActive: boolean;
}

export interface VendorOutstandingBalanceModel {
  vendorId: number;
  outstandingBalance: number;
}

// ---- Vendor cost ledger (informational, per hired trip - not
// auto-reconciled into vendor bills; see VendorBillModel for the formal
// billing side) ----

export interface VendorAdvanceModel {
  id: number;
  tripId: number;
  vendorId: number;
  amount: number;
  advanceDate: string;
  remarks: string | null;
  createdAt: string;
  createdBy: string | null;
}

export interface CreateVendorAdvanceRequest {
  vendorId: number;
  amount: number;
  advanceDate: string;
  remarks?: string;
}

export interface VendorDeductionModel {
  id: number;
  tripId: number;
  vendorId: number;
  amount: number;
  reason: string;
  deductionDate: string;
  createdAt: string;
  createdBy: string | null;
}

export interface CreateVendorDeductionRequest {
  vendorId: number;
  amount: number;
  reason: string;
  deductionDate: string;
}

// ---- Vendor bills / payments (formal billing, mirrors Invoice/Payment) ----

export interface VendorBillModel {
  id: number;
  vendorId: number;
  vendorName: string;
  tripId: number;
  billNo: string;
  billDate: string;
  dueDate: string;
  amount: number;
  statusId: number;
  statusName: string;
  paidAmount: number;
}

export interface VendorPaymentModel {
  id: number;
  paymentDate: string;
  amount: number;
  method: string;
  referenceNo: string | null;
}

export interface VendorBillDetailModel extends VendorBillModel {
  payments: VendorPaymentModel[];
}

// tripId is supplied by the URL, not this request body - amount is
// auto-computed server-side as VendorFreightAmount - sum(VendorDeductions).
export interface CreateVendorBillRequest {
  billNo: string;
  billDate: string;
  dueDate: string;
  statusId: number;
}

export interface CreateVendorPaymentRequest {
  paymentDate: string;
  amount: number;
  method: string;
  referenceNo?: string;
}

export interface VendorAgingReportLineModel {
  id: number;
  billNo: string;
  vendorId: number;
  vendorName: string;
  billDate: string;
  dueDate: string;
  outstandingAmount: number;
  daysOverdue: number;
}
