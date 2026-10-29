import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, throwError } from 'rxjs';
import { ToastService } from '../services/toast.service';

// Screens that already show their own inline error (login's red text under
// the form, the public tracking page's "no shipment found" state) skip the
// toast so the failure isn't reported to the user twice.
const SILENT_URL_FRAGMENTS = ['/auth/login', '/public/track'];

function messageFor(error: HttpErrorResponse): string {
  if (error.status === 0) {
    return 'Cannot reach the server. Check your connection and try again.';
  }

  const bodyMessage = (error.error as { message?: string } | null)?.message;
  if (bodyMessage) return bodyMessage;

  if (error.status === 403) return "You don't have permission to do that.";
  if (error.status === 404) return 'The requested item could not be found.';
  return error.status >= 500
    ? 'Something went wrong on our end. Please try again.'
    : 'That request could not be completed.';
}

/**
 * Central "global error -> toast" handling. Every list/form component in
 * this app used to fail silently (their `error:` subscribe callback just
 * flipped a loading flag) - this makes every failed HTTP call visible
 * without every screen needing its own error-toast boilerplate. Always
 * rethrows unchanged so callers that DO want to react (e.g. a form re-enabling
 * its submit button) still can.
 */
export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  const toast = inject(ToastService);

  return next(req).pipe(
    catchError((error: HttpErrorResponse) => {
      const isSilent = SILENT_URL_FRAGMENTS.some((fragment) => req.url.includes(fragment));

      // 401 is handled by authInterceptor's own redirect-to-login - a toast
      // on top of that redirect would just be noise.
      if (!isSilent && error.status !== 401) {
        toast.error(messageFor(error));
      }

      return throwError(() => error);
    }),
  );
};
