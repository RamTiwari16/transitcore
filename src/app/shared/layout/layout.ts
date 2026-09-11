import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs/operators';
import { toSignal } from '@angular/core/rxjs-interop';
import { MatIconModule } from '@angular/material/icon';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatSidenavModule } from '@angular/material/sidenav';
import { MatListModule } from '@angular/material/list';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { MatBadgeModule } from '@angular/material/badge';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { AuthService } from '../../services/auth-service';
import { ThemeService } from '../../core/services/theme.service';
import { LoadingService } from '../../core/services/loading.service';
import { NAV_GROUPS } from './nav-items';

@Component({
  selector: 'app-layout',
  imports: [
    CommonModule,
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    MatIconModule,
    MatToolbarModule,
    MatSidenavModule,
    MatListModule,
    MatButtonModule,
    MatMenuModule,
    MatBadgeModule,
    MatTooltipModule,
    MatFormFieldModule,
    MatInputModule,
    MatProgressBarModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './layout.html',
  styleUrl: './layout.scss',
})
export class Layout {
  private readonly router = inject(Router);
  private readonly authService = inject(AuthService);
  readonly themeService = inject(ThemeService);
  readonly loadingService = inject(LoadingService);

  readonly navGroups = NAV_GROUPS;
  readonly collapsed = signal(false);

  private readonly userData = this.authService.getUserData();
  readonly displayName = this.userData?.displayName ?? this.userData?.email ?? 'User';
  readonly email = this.userData?.email ?? '';
  readonly roles = this.userData?.roles ?? [];
  readonly avatarInitial = (this.displayName || '?').charAt(0).toUpperCase();

  private readonly currentUrl = toSignal(
    this.router.events.pipe(
      filter((event): event is NavigationEnd => event instanceof NavigationEnd),
    ),
    { initialValue: undefined },
  );

  readonly breadcrumb = computed(() => {
    this.currentUrl();
    const active = this.navGroups.flatMap((g) => g.items).find((item) => this.router.url.startsWith(item.path));
    return active?.label ?? 'Dashboard';
  });

  toggleSidenav(): void {
    this.collapsed.update((v) => !v);
  }

  toggleTheme(): void {
    this.themeService.toggle();
  }

  logout(): void {
    this.authService.logout();
    localStorage.removeItem('authToken');
    sessionStorage.clear();
    this.router.navigate(['/login']);
  }
}
