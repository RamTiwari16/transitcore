import { Routes } from '@angular/router';
import { unsavedChangesGuard } from '../../core/guards/unsaved-changes.guard';

export const OPS_ROUTES: Routes = [
  {
    path: 'trips',
    loadComponent: () => import('./trips-list/trips-list.component').then((m) => m.TripsListComponent),
  },
  {
    path: 'trips/new',
    loadComponent: () => import('./trip-form/trip-form.component').then((m) => m.TripFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'trips/:id',
    loadComponent: () => import('./trip-detail/trip-detail.component').then((m) => m.TripDetailComponent),
  },
  {
    path: 'routes',
    loadComponent: () => import('./routes-list/routes-list.component').then((m) => m.RoutesListComponent),
  },
  {
    path: 'routes/new',
    loadComponent: () => import('./route-form/route-form.component').then((m) => m.RouteFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'shipments',
    loadComponent: () =>
      import('./shipments-list/shipments-list.component').then((m) => m.ShipmentsListComponent),
  },
  {
    path: 'shipments/new',
    loadComponent: () =>
      import('./shipment-form/shipment-form.component').then((m) => m.ShipmentFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
];
