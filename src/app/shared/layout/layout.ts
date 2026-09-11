import { ChangeDetectionStrategy, Component, computed, effect, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { filter } from 'rxjs/operators';
import { toSignal } from '@angular/core/rxjs-interop';
import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';
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
  private readonly breakpointObserver = inject(BreakpointObserver);
  readonly themeService = inject(ThemeService);
  readonly loadingService = inject(LoadingService);

  readonly navGroups = NAV_GROUPS;
  readonly collapsed = signal(false);

  // Below the tablet breakpoint the sidenav becomes an overlay (mode="over",
  // closed by default) instead of a permanent 260px/72px column - a fixed-width
  // "side" nav has no room to coexist with content on a phone-width viewport.
  readonly isHandset = toSignal(
    this.breakpointObserver.observe([Breakpoints.Handset, Breakpoints.TabletPortrait]),
    { initialValue: { matches: false, breakpoints: {} } },
  );
  readonly sidenavMode = computed<'side' | 'over'>(() => (this.isHandset().matches ? 'over' : 'side'));
  readonly mobileOpen = signal(false);
  readonly sidenavOpened = computed(() => (this.isHandset().matches ? this.mobileOpen() : true));

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

  constructor() {
    // Close the overlay nav after navigating on a handset - it would
    // otherwise stay open on top of the page the user just picked.
    effect(() => {
      this.currentUrl();
      if (this.isHandset().matches) {
        this.mobileOpen.set(false);
      }
    });
  }

  toggleSidenav(): void {
    if (this.isHandset().matches) {
      this.mobileOpen.update((v) => !v);
    } else {
      this.collapsed.update((v) => !v);
    }
  }

  onSidenavOpenedChange(opened: boolean): void {
    if (this.isHandset().matches) {
      this.mobileOpen.set(opened);
    }
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
