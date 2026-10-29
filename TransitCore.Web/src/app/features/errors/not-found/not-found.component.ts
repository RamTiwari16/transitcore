import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { PageTitleService } from '../../../core/services/page-title.service';

@Component({
  selector: 'app-not-found',
  imports: [RouterLink, MatButtonModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="error-page">
      <span class="error-page__code">404</span>
      <h1>Page not found</h1>
      <p>The page you're looking for doesn't exist or has moved.</p>
      <a mat-flat-button color="primary" routerLink="/dashboard">Back to dashboard</a>
    </div>
  `,
  styleUrl: '../error-page.scss',
})
export class NotFoundComponent {
  constructor() {
    // Same reasoning as ForbiddenComponent - no nav item matches an
    // arbitrary invalid URL, so the topbar would otherwise show a stale/
    // wrong "Dashboard" instead of anything related to this page.
    const pageTitleService = inject(PageTitleService);
    pageTitleService.setTitle('Page Not Found');
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));
  }
}
