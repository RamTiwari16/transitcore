import { Routes } from '@angular/router';
import { unsavedChangesGuard } from '../../core/guards/unsaved-changes.guard';

export const VENDORS_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () => import('./vendors-list/vendors-list.component').then((m) => m.VendorsListComponent),
  },
  {
    path: 'new',
    loadComponent: () => import('./vendor-form/vendor-form.component').then((m) => m.VendorFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'bills/:id',
    loadComponent: () =>
      import('./vendor-bill-detail/vendor-bill-detail.component').then((m) => m.VendorBillDetailComponent),
  },
  {
    path: ':id/edit',
    loadComponent: () => import('./vendor-form/vendor-form.component').then((m) => m.VendorFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: ':id',
    loadComponent: () => import('./vendor-detail/vendor-detail.component').then((m) => m.VendorDetailComponent),
  },
];
