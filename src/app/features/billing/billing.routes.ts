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
    path: 'invoices/generate',
    loadComponent: () =>
      import('./generate-invoice/generate-invoice.component').then((m) => m.GenerateInvoiceComponent),
  },
  {
    path: 'invoices/aging-report',
    loadComponent: () =>
      import('./aging-report/aging-report.component').then((m) => m.AgingReportComponent),
  },
  {
    path: 'invoices/:id',
    loadComponent: () =>
      import('./invoice-detail/invoice-detail.component').then((m) => m.InvoiceDetailComponent),
  },
  {
    path: 'customers',
    loadComponent: () =>
      import('./customers-list/customers-list.component').then((m) => m.CustomersListComponent),
  },
  {
    path: 'rate-cards',
    loadComponent: () =>
      import('./rate-cards/rate-cards.component').then((m) => m.RateCardsComponent),
  },
];
