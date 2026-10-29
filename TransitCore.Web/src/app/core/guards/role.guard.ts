import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../../services/auth-service';
import { Role } from '../../constants/roles';

/**
 * Route-level role gate. Unlike authGuard (which only checks "is there a
 * session"), this checks the session actually has one of the allowed roles -
 * on failure it sends the user to /403, not /login, since they ARE
 * authenticated, just not permitted here.
 *
 * Usage: `canActivate: [roleGuard(['Admin', 'Manager'])]` on a route.
 */
export function roleGuard(allowedRoles: Role[]): CanActivateFn {
  return () => {
    const auth = inject(AuthService);
    const router = inject(Router);

    const userRoles = auth.getRoles();
    const isAllowed = userRoles.some((role) => allowedRoles.includes(role as Role));

    return isAllowed ? true : router.createUrlTree(['/403']);
  };
}
