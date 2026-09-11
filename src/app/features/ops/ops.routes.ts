import { Routes } from '@angular/router';
import { unsavedChangesGuard } from '../../core/guards/unsaved-changes.guard';

export const OPS_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () => import('./trips-list/trips-list.component').then((m) => m.TripsListComponent),
  },
  {
    path: 'new',
    loadComponent: () => import('./trip-form/trip-form.component').then((m) => m.TripFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: ':id',
    loadComponent: () => import('./trip-detail/trip-detail.component').then((m) => m.TripDetailComponent),
  },
];
