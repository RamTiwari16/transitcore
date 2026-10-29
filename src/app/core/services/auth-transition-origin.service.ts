import { Injectable } from '@angular/core';

// The login/logout circular-wipe transition (app.config.ts) needs the
// screen point to expand/collapse around, but the router's
// onViewTransitionCreated hook has no access to the click that triggered
// the navigation - login.ts and layout.ts capture it here just before
// navigating, and the hook reads it back when the transition starts.
@Injectable({ providedIn: 'root' })
export class AuthTransitionOriginService {
  x = window.innerWidth / 2;
  y = window.innerHeight / 2;

  capture(x: number, y: number): void {
    this.x = x;
    this.y = y;
  }
}
