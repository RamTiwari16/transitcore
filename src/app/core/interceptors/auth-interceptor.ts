import {
  HttpInterceptorFn,
  HttpErrorResponse
} from '@angular/common/http';

import { inject } from '@angular/core';

import { Router } from '@angular/router';

import { catchError } from 'rxjs/operators';

import { throwError } from 'rxjs';

import { AuthService } from '../../services/auth-service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {

  const router = inject(Router);
  const auth = inject(AuthService);

  const token = auth.getToken();

  let isRedirecting = false;

  // Skip login API
  const isLoginRequest =
    req.url.includes('/auth/login');

  // Attach token
  const clonedReq =
    token && !isLoginRequest
      ? req.clone({
          setHeaders: {
            Authorization: `Bearer ${token}`
          }
        })
      : req;

  return next(clonedReq).pipe(

    catchError((error: HttpErrorResponse) => {

      if (error.status === 401) {

        console.warn('Unauthorized');

        // Clears the stored session (not just sessionStorage, which never
        // held it - the encrypted session lives in localStorage) so a
        // reload after a 401 doesn't still look authenticated.
        auth.logout();
        sessionStorage.clear();

        if (!isRedirecting) {

          isRedirecting = true;

          router.navigate(['login'])
            .then(() => {

              isRedirecting = false;
            });
        }
      }

      return throwError(() => error);
    })
  );
};