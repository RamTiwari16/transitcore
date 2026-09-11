import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { MatTableModule } from '@angular/material/table';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatDialog } from '@angular/material/dialog';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { BillingService } from '../../../services/billing.service';
import { ToastService } from '../../../core/services/toast.service';
import { CustomerModel, CreateCustomerRequest } from '../../../models/billing.models';
import { AddCustomerDialogComponent } from './add-customer-dialog.component';

@Component({
  selector: 'app-customers-list',
  imports: [MatTableModule, MatButtonModule, MatIconModule, EmptyStateComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './customers-list.component.html',
  styleUrl: './customers-list.component.scss',
})
export class CustomersListComponent {
  private readonly dialog = inject(MatDialog);

  readonly customers = signal<CustomerModel[]>([]);
  readonly loading = signal(true);
  readonly displayedColumns = ['code', 'name', 'isActive'];

  constructor(
    private billingService: BillingService,
    private toast: ToastService,
  ) {
    this.load();
  }

  private load(): void {
    this.loading.set(true);
    this.billingService.getCustomers(false).subscribe({
      next: (customers) => {
        this.customers.set(customers);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  openAddCustomerDialog(): void {
    this.dialog
      .open(AddCustomerDialogComponent, { width: '420px' })
      .afterClosed()
      .subscribe((request: CreateCustomerRequest | undefined) => {
        if (!request) return;

        this.billingService.createCustomer(request).subscribe({
          next: () => {
            this.toast.success('Customer added successfully');
            this.load();
          },
          error: (err) => this.toast.error(err?.error?.message || 'Failed to add customer'),
        });
      });
  }
}
