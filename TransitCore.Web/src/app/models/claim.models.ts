export interface ClaimFilter {
  shipmentId?: number;
  statusId?: number;
  fromDate?: string;
  toDate?: string;
}

export interface ClaimModel {
  id: number;
  shipmentId: number;
  trackingNo: string;
  claimantName: string;
  claimantPhone: string | null;
  amountClaimed: number;
  statusId: number;
  statusName: string;
  settledAmount: number | null;
  settlementMethod: string | null;
  notes: string | null;
  createdAt: string;
}

export interface ClaimStatusHistoryModel {
  id: number;
  statusId: number;
  statusName: string;
  changedAt: string;
  notes: string | null;
}

export interface ClaimDetailModel extends ClaimModel {
  statusHistory: ClaimStatusHistoryModel[];
}

export interface CreateClaimRequest {
  shipmentId: number;
  claimantName: string;
  claimantPhone?: string;
  amountClaimed: number;
  statusId: number;
  notes?: string;
}

export interface UpdateClaimRequest {
  claimId: number;
  claimantName: string;
  claimantPhone?: string;
  amountClaimed: number;
  notes?: string;
}

export interface UpdateClaimStatusRequest {
  claimId: number;
  statusId: number;
  notes?: string;
}

// settlementMethod must be one of InvoiceDeduction / CreditNote / Insurance /
// DriverRecovery / VendorRecovery.
export interface SettleClaimRequest {
  claimId: number;
  settledAmount: number;
  settlementMethod: string;
  notes?: string;
}

export const CLAIM_SETTLEMENT_METHODS = [
  'InvoiceDeduction',
  'CreditNote',
  'Insurance',
  'DriverRecovery',
  'VendorRecovery',
] as const;
