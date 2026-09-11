import { Routes } from '@angular/router';

export const BILLING_ROUTES: Routes = [
  {
    path: 'invoices',
    loadComponent: () =>
      import('./invoices-list/invoices-list.component').then((m) => m.InvoicesListComponent),
  },
  {
    path: 'customers',
    loadComponent: () =>
      import('./customers-list/customers-list.component').then((m) => m.CustomersListComponent),
  },
];
