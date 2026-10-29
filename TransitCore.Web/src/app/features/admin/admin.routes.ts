import { Routes } from '@angular/router';
import { unsavedChangesGuard } from '../../core/guards/unsaved-changes.guard';

export const ADMIN_ROUTES: Routes = [
  {
    path: 'users',
    loadComponent: () => import('./users-list/users-list.component').then((m) => m.UsersListComponent),
  },
  {
    path: 'users/new',
    loadComponent: () => import('./user-form/user-form.component').then((m) => m.UserFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'users/:id/edit',
    loadComponent: () => import('./user-form/user-form.component').then((m) => m.UserFormComponent),
    canDeactivate: [unsavedChangesGuard],
  },
  {
    path: 'master-data',
    loadComponent: () => import('./master-data/master-data.component').then((m) => m.MasterDataComponent),
  },
];
