import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
import { BillingService } from '../../../services/billing.service';
import { InvoiceModel } from '../../../models/billing.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createClientPagedListState } from '../../../shared/util/client-paged-list-state';

@Component({
  selector: 'app-invoices-list',
  imports: [
    RouterLink,
    MatButtonModule,
    MatIconModule,
    MatProgressSpinnerModule,
    MatTooltipModule,
    DataTableComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './invoices-list.component.html',
  styleUrl: './invoices-list.component.scss',
})
export class InvoicesListComponent {
  private readonly billingService = inject(BillingService);
  private readonly router = inject(Router);

  readonly downloadingId = signal<number | null>(null);

  readonly columns = computed<DataTableColumn<InvoiceModel>[]>(() => [
    { key: 'invoiceNo', label: 'Invoice No', sortable: true, cell: (row) => row.invoiceNo },
    { key: 'customerName', label: 'Customer', cell: (row) => row.customerName },
    { key: 'invoiceDate', label: 'Invoice Date', cell: (row) => this.formatDate(row.invoiceDate) },
    { key: 'dueDate', label: 'Due Date', cell: (row) => this.formatDate(row.dueDate) },
    { key: 'totalAmount', label: 'Total', cell: (row) => this.formatCurrency(row.totalAmount) },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
  ]);

  readonly list = createClientPagedListState<InvoiceModel>(() => this.billingService.getInvoices({}));

  constructor() {
    this.list.load();
  }

  rowId = (row: InvoiceModel): number => row.id;

  openInvoice(row: InvoiceModel): void {
    this.router.navigate(['/billing/invoices', row.id]);
  }

  downloadPdf(row: InvoiceModel): void {
    if (this.downloadingId() !== null) return;

    this.downloadingId.set(row.id);
    this.billingService.getInvoicePdf(row.id).subscribe({
      next: (blob) => {
        this.downloadingId.set(null);
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${row.invoiceNo}.pdf`;
        link.click();
        URL.revokeObjectURL(url);
      },
      // errorInterceptor already toasts the failure - just clear the
      // in-flight flag so the button re-enables.
      error: () => this.downloadingId.set(null),
    });
  }

  private formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
  }

  private formatDate(value: string): string {
    return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
