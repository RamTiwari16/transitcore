import { Routes } from '@angular/router';
import { unsavedChangesGuard } from '../../core/guards/unsaved-changes.guard';

export const BILLING_ROUTES: Routes = [
  {
    path: 'invoices',
    loadComponent: () =>
      import('./invoices-list/invoices-list.component').then((m) => m.InvoicesListComponent),
  },
  {
    path: 'invoices/new',
    loadComponent: () =>
      import('./invoice-form/invoice-form.component').then((m) => m.InvoiceFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'customers',
    loadComponent: () =>
      import('./customers-list/customers-list.component').then((m) => m.CustomersListComponent),
  },
];
