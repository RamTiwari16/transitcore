import { Routes } from '@angular/router';
import { Login } from './Pages/login/login';
import { Layout } from './shared/layout/layout';
import { VehicleOrder } from './Pages/vehicle-order/vehicle-order';
import { BulkUpload } from './Pages/bulk-upload/bulk-upload';
import { authGuard } from './core/guards/auth.guard';
import { roleGuard } from './core/guards/role.guard';

export const routes: Routes = [
    { path: '', redirectTo: 'login', pathMatch: 'full' },
    { path: 'login', component: Login },
    // Public, unauthenticated shipment tracking - deliberately outside the
    // authGuard'd Layout tree below, backed by the equally public
    // /api/v1/public/track endpoint (see PublicController on the backend).
    {
        path: 'track',
        loadComponent: () => import('./Pages/track/track.component').then((m) => m.TrackComponent),
    },
    {
        path: 'track/:trackingNo',
        loadComponent: () => import('./Pages/track/track.component').then((m) => m.TrackComponent),
    },
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
            {
                path: 'vendors',
                loadChildren: () => import('./features/vendors/vendors.routes').then((m) => m.VENDORS_ROUTES),
            },
            {
                path: 'claims',
                loadChildren: () => import('./features/claims/claims.routes').then((m) => m.CLAIMS_ROUTES),
            },
            {
                path: 'reports',
                loadComponent: () =>
                    import('./features/reports/reports.component').then((m) => m.ReportsComponent),
                canActivate: [roleGuard(['Admin', 'Manager'])],
            },
            {
                path: 'admin',
                loadChildren: () => import('./features/admin/admin.routes').then((m) => m.ADMIN_ROUTES),
                canActivate: [roleGuard(['Admin'])],
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
