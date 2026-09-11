import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { MatTableModule } from '@angular/material/table';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { BillingService } from '../../../services/billing.service';
import { InvoiceModel } from '../../../models/billing.models';

@Component({
  selector: 'app-invoices-list',
  imports: [MatTableModule, EmptyStateComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './invoices-list.component.html',
  styleUrl: './invoices-list.component.scss',
})
export class InvoicesListComponent {
  readonly invoices = signal<InvoiceModel[]>([]);
  readonly loading = signal(true);
  readonly displayedColumns = ['invoiceNo', 'customerName', 'invoiceDate', 'dueDate', 'totalAmount', 'statusName'];

  constructor(private billingService: BillingService) {
    this.billingService.getInvoices({}).subscribe({
      next: (invoices) => {
        this.invoices.set(invoices);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
  }

  formatDate(value: string): string {
    return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
