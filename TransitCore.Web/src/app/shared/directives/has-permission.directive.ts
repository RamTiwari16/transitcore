import { Directive, Input, TemplateRef, ViewContainerRef, inject } from '@angular/core';
import { AuthService } from '../../services/auth-service';
import { Role } from '../../constants/roles';

/**
 * Structural directive, same shape as *ngIf: renders its host template only
 * if the current user has at least one of the given roles.
 *
 * `<button *appHasPermission="'Admin'">Delete</button>`
 * `<button *appHasPermission="['Admin', 'Manager']">Assign</button>`
 */
@Directive({
  selector: '[appHasPermission]',
})
export class HasPermissionDirective {
  private readonly templateRef = inject(TemplateRef<unknown>);
  private readonly viewContainer = inject(ViewContainerRef);
  private readonly authService = inject(AuthService);

  private hasView = false;

  @Input() set appHasPermission(allowedRoles: Role | Role[]) {
    const roles = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];
    const userRoles = this.authService.getRoles();
    const isAllowed = roles.some((role) => userRoles.includes(role));

    if (isAllowed && !this.hasView) {
      this.viewContainer.createEmbeddedView(this.templateRef);
      this.hasView = true;
    } else if (!isAllowed && this.hasView) {
      this.viewContainer.clear();
      this.hasView = false;
    }
  }
}
