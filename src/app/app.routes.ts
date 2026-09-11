import { Routes } from '@angular/router';
import { Login } from './Pages/login/login';
import { Layout } from './shared/layout/layout';
import { VehicleOrder } from './Pages/vehicle-order/vehicle-order';
import { BulkUpload } from './Pages/bulk-upload/bulk-upload';


export const routes: Routes = [
    { path: '', redirectTo: 'login', pathMatch: 'full' },
    { path: 'login', component: Login },
    {
        path: '', component: Layout,
        children: [
            {
                path: 'vehicleOrder', component: VehicleOrder
            },
            {
                path: 'bulkupload', component: BulkUpload
            },
            
        ]
    }

];
