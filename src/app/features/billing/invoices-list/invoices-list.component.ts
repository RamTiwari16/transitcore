import { ChangeDetectionStrategy, Component, computed, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
import { PageEvent } from '@angular/material/paginator';
import { Sort } from '@angular/material/sort';
import { BillingService } from '../../../services/billing.service';
import { ToastService } from '../../../core/services/toast.service';
import { InvoiceModel } from '../../../models/billing.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';

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
  private readonly allInvoices = signal<InvoiceModel[]>([]);
  readonly loading = signal(true);
  readonly pageIndex = signal(0);
  readonly pageSize = signal(10);
  readonly downloadingId = signal<number | null>(null);

  readonly totalCount = computed(() => this.allInvoices().length);
  readonly rows = computed(() => {
    const start = this.pageIndex() * this.pageSize();
    return this.allInvoices().slice(start, start + this.pageSize());
  });

  readonly columns = computed<DataTableColumn<InvoiceModel>[]>(() => [
    { key: 'invoiceNo', label: 'Invoice No', sortable: true, cell: (row) => row.invoiceNo },
    { key: 'customerName', label: 'Customer', cell: (row) => row.customerName },
    { key: 'invoiceDate', label: 'Invoice Date', cell: (row) => this.formatDate(row.invoiceDate) },
    { key: 'dueDate', label: 'Due Date', cell: (row) => this.formatDate(row.dueDate) },
    { key: 'totalAmount', label: 'Total', cell: (row) => this.formatCurrency(row.totalAmount) },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
  ]);

  constructor(
    private billingService: BillingService,
    private toast: ToastService,
  ) {
    this.billingService.getInvoices({}).subscribe({
      next: (invoices) => {
        this.allInvoices.set(invoices);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.toast.error('Failed to load invoices');
      },
    });
  }

  onPage(event: PageEvent): void {
    this.pageIndex.set(event.pageIndex);
    this.pageSize.set(event.pageSize);
  }

  onSort(_sort: Sort): void {
    // Client-side pagination only for now - see onSort comment on
    // VehiclesListComponent for the server-side-sort follow-up note.
  }

  rowId = (row: InvoiceModel): number => row.id;

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
      error: () => {
        this.downloadingId.set(null);
        this.toast.error('Failed to generate invoice PDF');
      },
    });
  }

  private formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
  }

  private formatDate(value: string): string {
    return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
