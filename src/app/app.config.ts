import {
  ApplicationConfig,
  ErrorHandler,
  inject,
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
import { AuthTransitionOriginService } from './core/services/auth-transition-origin.service';

// Login and logout each swap the *entire* page rather than just the routed
// content inside it - Login is a sibling route to Layout, not nested under
// it (app.routes.ts) - so both get the same circular blur wipe as the
// theme toggle (layout.ts) instead of the small main-content fade every
// other route change gets (styles.scss): login expands it from the sign-in
// button outward, logout collapses it back down to whichever logout button
// was clicked. `from`/`to` are the root of their route trees, so matching
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

  // onViewTransitionCreated runs in an injection context (Angular's own
  // docs on the option), so this can read the click position login.ts /
  // layout.ts captured instead of needing it threaded in as an argument.
  const { x, y } = inject(AuthTransitionOriginService);
  const endRadius = Math.hypot(
    Math.max(x, window.innerWidth - x),
    Math.max(y, window.innerHeight - y)
  );

  // .app-shell__main only carries its view-transition-name once
  // mainContentTransitionReady flips true (layout.ts/.scss) - never true yet
  // on login success, since Layout has just this instant been created, so
  // there's nothing to suppress on that side. Logout is the mirror image:
  // the shell has been live for a while and does carry the name, but the
  // browser decides which elements get their own transition snapshot the
  // moment this navigation starts, before this hook even runs - too late to
  // undo here, so logout() (layout.ts) already clears it before navigating.
  if (loggingOut) {
    // Logout collapses the *old* dashboard away instead of the new (login)
    // view expanding over it, so the layer doing the clip-path animation
    // flips - this class (styles.scss) swaps which one sits on top to match.
    document.documentElement.classList.add('vt-collapse-old');
  }

  transition.ready.then(() => {
    if (loggingOut) {
      // Dashboard shrinks away to the clicked logout button, revealing the
      // login page underneath - same recipe as the theme toggle, mirrored.
      document.documentElement.animate(
        {
          clipPath: [`circle(${endRadius}px at ${x}px ${y}px)`, `circle(0px at ${x}px ${y}px)`],
          filter: ['blur(0px)', 'blur(28px)']
        },
        { duration: 750, easing: 'cubic-bezier(0.4, 0, 1, 1)', pseudoElement: '::view-transition-old(root)' }
      );
    } else {
      // Dashboard grows in from the sign-in button over the login page.
      document.documentElement.animate(
        {
          clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${endRadius}px at ${x}px ${y}px)`],
          filter: ['blur(28px)', 'blur(0px)']
        },
        { duration: 750, easing: 'cubic-bezier(0, 0, 0.2, 1)', pseudoElement: '::view-transition-new(root)' }
      );
    }
  });

  transition.finished.finally(() => {
    document.documentElement.classList.remove('vt-collapse-old');
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
      withViewTransitions({ skipInitialTransition: true, onViewTransitionCreated: handleAuthTransition })
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
