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
    path: 'drivers',
    loadComponent: () =>
      import('./drivers-list/drivers-list.component').then((m) => m.DriversListComponent),
  },
];
