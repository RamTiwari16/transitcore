import { Routes } from '@angular/router';

export const CLAIMS_ROUTES: Routes = [
  {
    path: '',
    loadComponent: () => import('./claims-list/claims-list.component').then((m) => m.ClaimsListComponent),
  },
  {
    path: ':id',
    loadComponent: () => import('./claim-detail/claim-detail.component').then((m) => m.ClaimDetailComponent),
  },
];
