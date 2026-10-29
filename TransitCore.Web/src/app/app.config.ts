import {
  ApplicationConfig,
  ErrorHandler,
  provideBrowserGlobalErrorListeners
} from '@angular/core';

import {
  provideRouter,
  withHashLocation,
  withViewTransitions,
  type ActivatedRouteSnapshot,
  type ViewTransitionInfo
} from '@angular/router';

import {
  provideHttpClient,
  withInterceptors
} from '@angular/common/http';

import { provideAnimations } from '@angular/platform-browser/animations';

import { provideToastr } from 'ngx-toastr';

import { routes } from './app.routes';
import { authInterceptor } from './core/interceptors/auth-interceptor';
import { errorInterceptor } from './core/interceptors/error-interceptor';
import { loadingInterceptor } from './core/interceptors/loading-interceptor';
import { GlobalErrorHandler } from './core/services/global-error-handler';

// Login and logout each swap the *entire* page rather than just the routed
// content inside it - Login is a sibling route to Layout, not nested under
// it (app.routes.ts) - so both get one full-viewport blur dissolve instead
// of the small main-content fade every other route change gets
// (styles.scss). `from`/`to` are the root of their route trees, so matching
// has to walk down to the activated leaf rather than reading
// `snapshot.routeConfig` directly.
function isLoginRoute(snapshot: ActivatedRouteSnapshot): boolean {
  for (let node: ActivatedRouteSnapshot | null = snapshot; node; node = node.firstChild) {
    if (node.routeConfig?.path === 'login') {
      return true;
    }
  }
  return false;
}

function handleAuthTransition({ transition, from, to }: ViewTransitionInfo): void {
  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const loggingOut = isLoginRoute(to);
  const loggingIn = isLoginRoute(from);

  if (prefersReducedMotion || (!loggingOut && !loggingIn)) {
    return;
  }

  // .app-shell__main carries its own view-transition-name (layout.scss) so
  // in-app page changes stay scoped away from the rail/topbar. Neither side
  // of an auth transition needs that: logout has nothing left to scope once
  // the shell is gone, and login success has no rail/topbar yet to protect.
  // Left in place, main-content would just double up with this dissolve as
  // a second, slightly-offset animation layered on top of it.
  let mainEl: HTMLElement | null = null;

  if (loggingOut) {
    // Shell is still live right now and is about to be destroyed - no need
    // to restore this afterward.
    mainEl = document.querySelector<HTMLElement>('.app-shell__main');
    mainEl?.style.setProperty('view-transition-name', 'none');
  } else {
    // Dashboard doesn't exist until the router finishes swapping in the new
    // route - updateCallbackDone fires right after that, and before the
    // browser captures the "new" snapshot that view-transition-name would
    // affect. This page sticks around afterward, so it does need restoring.
    transition.updateCallbackDone.then(() => {
      mainEl = document.querySelector<HTMLElement>('.app-shell__main');
      mainEl?.style.setProperty('view-transition-name', 'none');
    });
  }

  transition.ready.then(() => {
    document.documentElement.animate(
      { opacity: [1, 0], filter: ['blur(0px)', 'blur(18px)'] },
      { duration: 450, easing: 'cubic-bezier(0.4, 0, 1, 1)', pseudoElement: '::view-transition-old(root)' }
    );
    document.documentElement.animate(
      { opacity: [0, 1], filter: ['blur(18px)', 'blur(0px)'] },
      { duration: 500, easing: 'cubic-bezier(0, 0, 0.2, 1)', pseudoElement: '::view-transition-new(root)' }
    );
  });

  transition.finished.finally(() => {
    mainEl?.style.removeProperty('view-transition-name');
  });
}

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),

    provideRouter(
      routes,
      withHashLocation(),
      // Crossfades the main content between routes using the native View
      // Transitions API (see styles.scss for the page-content keyframes).
      // No-ops silently on browsers that don't support it.
      withViewTransitions({ onViewTransitionCreated: handleAuthTransition })
    ),

    provideHttpClient(
      withInterceptors([
        authInterceptor,
        errorInterceptor,
        loadingInterceptor
      ])
    ),

    provideAnimations(),

    provideToastr({
      timeOut: 3000,
      positionClass: 'toast-top-right',
      preventDuplicates: true,
    }),

    { provide: ErrorHandler, useClass: GlobalErrorHandler },
  ]
};
