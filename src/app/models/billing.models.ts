export interface CustomerModel {
  id: number;
  code: string;
  name: string;
  isActive: boolean;
}

export interface CreateCustomerRequest {
  code: string;
  name: string;
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
  taxAmount: number;
  totalAmount: number;
  statusId: number;
  statusName: string;
}

export interface InvoiceLineModel {
  id: number;
  shipmentId: number | null;
  description: string;
  quantity: number;
  unitPrice: number;
  lineTotal: number;
}

export interface InvoiceDetailModel extends InvoiceModel {
  lines: InvoiceLineModel[];
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
