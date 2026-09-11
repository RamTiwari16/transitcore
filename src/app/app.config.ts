// import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
// import { provideRouter, withHashLocation } from '@angular/router';

// import { routes } from './app.routes';
// import { provideToastr } from 'ngx-toastr';

// export const appConfig: ApplicationConfig = {
//   providers: [
//     provideBrowserGlobalErrorListeners(),
//     provideRouter(routes),
//         provideRouter(routes,withHashLocation()),
//      provideToastr({
//       timeOut: 3000,
//       positionClass: 'toast-top-right',
//       preventDuplicates: true,
//     }),
//   ]
// };

import {
  ApplicationConfig,
  provideBrowserGlobalErrorListeners
} from '@angular/core';

import {
  provideRouter,
  withHashLocation
} from '@angular/router';

import {
  provideHttpClient,
  withInterceptors
} from '@angular/common/http';

import { provideAnimations } from '@angular/platform-browser/animations';

import { provideToastr } from 'ngx-toastr';

import { routes } from './app.routes';
import { authInterceptor } from './core/interceptors/auth-interceptor';



export const appConfig: ApplicationConfig = {

  providers: [

    provideBrowserGlobalErrorListeners(),

    provideRouter(
      routes,
      withHashLocation()
    ),

    provideHttpClient(
      withInterceptors([
        authInterceptor
      ])
    ),

    provideAnimations(),

    provideToastr({
      timeOut: 3000,
      positionClass: 'toast-top-right',
      preventDuplicates: true,
    })

  ]

};