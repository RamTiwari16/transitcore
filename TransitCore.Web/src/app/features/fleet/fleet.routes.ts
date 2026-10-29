import { Routes } from '@angular/router';
import { unsavedChangesGuard } from '../../core/guards/unsaved-changes.guard';

export const FLEET_ROUTES: Routes = [
  {
    path: 'vehicles',
    loadComponent: () =>
      import('./vehicles-list/vehicles-list.component').then((m) => m.VehiclesListComponent),
  },
  {
    path: 'vehicles/new',
    loadComponent: () =>
      import('./vehicle-form/vehicle-form.component').then((m) => m.VehicleFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'vehicles/:id/edit',
    loadComponent: () =>
      import('./vehicle-form/vehicle-form.component').then((m) => m.VehicleFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'vehicles/:id',
    loadComponent: () =>
      import('./vehicle-detail/vehicle-detail.component').then((m) => m.VehicleDetailComponent),
  },
  {
    path: 'drivers',
    loadComponent: () =>
      import('./drivers-list/drivers-list.component').then((m) => m.DriversListComponent),
  },
  {
    path: 'drivers/new',
    loadComponent: () =>
      import('./driver-form/driver-form.component').then((m) => m.DriverFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'drivers/:id/edit',
    loadComponent: () =>
      import('./driver-form/driver-form.component').then((m) => m.DriverFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'drivers/:id',
    loadComponent: () =>
      import('./driver-detail/driver-detail.component').then((m) => m.DriverDetailComponent),
  },
];
