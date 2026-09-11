import {
  HttpInterceptorFn,
  HttpErrorResponse
} from '@angular/common/http';

import { inject } from '@angular/core';

import { Router } from '@angular/router';

import { catchError } from 'rxjs/operators';

import { throwError } from 'rxjs';

export const authInterceptor: HttpInterceptorFn = (req, next) => {

  const router = inject(Router);

  const token =
    localStorage.getItem('authToken');

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