import { Routes } from '@angular/router';
import { unsavedChangesGuard } from '../../core/guards/unsaved-changes.guard';

export const FLEET_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./vehicles-list/vehicles-list.component').then((m) => m.VehiclesListComponent),
  },
  {
    path: 'new',
    loadComponent: () =>
      import('./vehicle-form/vehicle-form.component').then((m) => m.VehicleFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
];
