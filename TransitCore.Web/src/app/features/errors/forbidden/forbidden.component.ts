import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { PageTitleService } from '../../../core/services/page-title.service';

@Component({
  selector: 'app-forbidden',
  imports: [RouterLink, MatButtonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="error-page">
      <span class="error-page__code">403</span>
      <h1>Access denied</h1>
      <p>You don't have permission to view this page.</p>
      <a mat-flat-button color="primary" routerLink="/dashboard">Back to dashboard</a>
    </div>
  `,
  styleUrl: '../error-page.scss',
})
export class ForbiddenComponent {
  constructor() {
    // No nav item's path matches /403, so the topbar's breadcrumb fallback
    // would otherwise show a stale/wrong "Dashboard" here instead of
    // anything related to this page (kept as its own <h1> too - unlike a
    // regular section header, "Access denied" is the actual content of
    // this page, not a duplicate of a nav label).
    const pageTitleService = inject(PageTitleService);
    pageTitleService.setTitle('Access Denied');
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));
  }
}
