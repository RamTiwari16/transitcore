import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatDialog } from '@angular/material/dialog';
import { BillingService } from '../../../services/billing.service';
import { ToastService } from '../../../core/services/toast.service';
import { CustomerModel } from '../../../models/billing.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createClientPagedListState } from '../../../shared/util/client-paged-list-state';
import { AddCustomerDialogComponent, AddCustomerDialogResult } from './add-customer-dialog.component';

@Component({
  selector: 'app-customers-list',
  imports: [MatButtonModule, MatIconModule, MatTooltipModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './customers-list.component.html',
  styleUrl: './customers-list.component.scss',
})
export class CustomersListComponent {
  private readonly dialog = inject(MatDialog);
  private readonly billingService = inject(BillingService);
  private readonly toast = inject(ToastService);

  readonly columns = computed<DataTableColumn<CustomerModel>[]>(() => [
    { key: 'code', label: 'Code', sortable: true, cell: (row) => row.code },
    { key: 'name', label: 'Name', sortable: true, cell: (row) => row.name },
    { key: 'isActive', label: 'Status', cell: (row) => (row.isActive ? 'Active' : 'Inactive') },
  ]);

  readonly list = createClientPagedListState<CustomerModel>(() => this.billingService.getCustomers(false));

  constructor() {
    this.list.load();
  }

  rowId = (row: CustomerModel): number => row.id;

  openAddCustomerDialog(): void {
    this.dialog
      .open(AddCustomerDialogComponent, { width: '420px' })
      .afterClosed()
      .subscribe((result: AddCustomerDialogResult | undefined) => this.handleDialogResult(result));
  }

  openEditCustomerDialog(customer: CustomerModel): void {
    this.dialog
      .open(AddCustomerDialogComponent, { width: '420px', data: { customer } })
      .afterClosed()
      .subscribe((result: AddCustomerDialogResult | undefined) => this.handleDialogResult(result));
  }

  private handleDialogResult(result: AddCustomerDialogResult | undefined): void {
    if (!result) return;

    const save$: Observable<unknown> =
      result.mode === 'create'
        ? this.billingService.createCustomer(result.request)
        : this.billingService.updateCustomer(result.request);

    save$.subscribe({
      next: () => {
        this.toast.success(result.mode === 'create' ? 'Customer added successfully' : 'Customer updated successfully');
        this.list.load();
      },
      // errorInterceptor already toasts the failure.
    });
  }
}
