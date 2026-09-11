import { Routes } from '@angular/router';
import { Login } from './Pages/login/login';
import { Layout } from './shared/layout/layout';
import { VehicleOrder } from './Pages/vehicle-order/vehicle-order';
import { BulkUpload } from './Pages/bulk-upload/bulk-upload';
import { authGuard } from './core/guards/auth.guard';

export const routes: Routes = [
    { path: '', redirectTo: 'login', pathMatch: 'full' },
    { path: 'login', component: Login },
    {
        path: '',
        component: Layout,
        canActivate: [authGuard],
        children: [
            { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
            {
                path: 'dashboard',
                loadComponent: () =>
                    import('./features/dashboard/dashboard.component').then((m) => m.DashboardComponent),
            },
            {
                path: 'fleet',
                loadChildren: () => import('./features/fleet/fleet.routes').then((m) => m.FLEET_ROUTES),
            },
            {
                path: 'ops',
                loadChildren: () => import('./features/ops/ops.routes').then((m) => m.OPS_ROUTES),
            },
            {
                path: 'billing',
                loadChildren: () => import('./features/billing/billing.routes').then((m) => m.BILLING_ROUTES),
            },
            { path: 'vehicle-order', component: VehicleOrder },
            { path: 'bulk-upload', component: BulkUpload },
            {
                path: '403',
                loadComponent: () =>
                    import('./features/errors/forbidden/forbidden.component').then((m) => m.ForbiddenComponent),
            },
            {
                path: '**',
                loadComponent: () =>
                    import('./features/errors/not-found/not-found.component').then((m) => m.NotFoundComponent),
            },
        ],
    },
];
