import { ChangeDetectionStrategy, Component, ElementRef, HostListener, computed, effect, inject, signal } from '@angular/core';
import { NavigationEnd, Router, RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { catchError, debounceTime, distinctUntilChanged, filter, switchMap } from 'rxjs/operators';
import { of } from 'rxjs';
import { toObservable, toSignal } from '@angular/core/rxjs-interop';
import { BreakpointObserver, Breakpoints } from '@angular/cdk/layout';
import { MatIconModule } from '@angular/material/icon';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { MatMenuModule } from '@angular/material/menu';
import { MatBadgeModule } from '@angular/material/badge';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { AuthService } from '../../services/auth-service';
import { SearchService } from '../../services/search.service';
import { SearchResultModel } from '../../models/search.models';
import { ThemeService } from '../../core/services/theme.service';
import { LoadingService } from '../../core/services/loading.service';
import { PageTitleService } from '../../core/services/page-title.service';
import { NAV_GROUPS, NavGroup } from './nav-items';

interface SearchResultGroup {
  entityType: string;
  items: SearchResultModel[];
}

// Which route a search result navigates to, per entity type. Shipment,
// Route, and Customer have no detail page in the app - those open their
// list page instead of a specific record (a deliberate scope decision, not
// an oversight). User has an edit page but no dedicated detail page.
const SEARCH_RESULT_ROUTES: Record<string, (id: number) => (string | number)[]> = {
  Trip: (id) => ['/ops/trips', id],
  Vehicle: (id) => ['/fleet/vehicles', id],
  Driver: (id) => ['/fleet/drivers', id],
  Invoice: (id) => ['/billing/invoices', id],
  Shipment: () => ['/ops/shipments'],
  Route: () => ['/ops/routes'],
  Customer: () => ['/billing/customers'],
  User: (id) => ['/admin/users', id, 'edit'],
};

@Component({
  selector: 'app-layout',
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    MatIconModule,
    MatToolbarModule,
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
  private readonly searchService = inject(SearchService);
  private readonly elementRef = inject(ElementRef);
  readonly themeService = inject(ThemeService);
  readonly loadingService = inject(LoadingService);
  private readonly pageTitleService = inject(PageTitleService);

  readonly searchTerm = signal('');
  readonly searchOpen = signal(false);
  readonly searchResults = toSignal(
    toObservable(this.searchTerm).pipe(
      debounceTime(300),
      distinctUntilChanged(),
      switchMap((term) =>
        term.trim().length < 2
          ? of([] as SearchResultModel[])
          : this.searchService.search(term.trim()).pipe(catchError(() => of([] as SearchResultModel[]))),
      ),
    ),
    { initialValue: [] as SearchResultModel[] },
  );
  readonly groupedResults = computed<SearchResultGroup[]>(() => {
    const groups = new Map<string, SearchResultModel[]>();
    for (const result of this.searchResults()) {
      const bucket = groups.get(result.entityType);
      if (bucket) bucket.push(result);
      else groups.set(result.entityType, [result]);
    }
    return Array.from(groups, ([entityType, items]) => ({ entityType, items }));
  });

  // Filtered once at construction (roles don't change within a session) -
  // purely a UX nicety that hides links a user can't use; the real gate is
  // roleGuard on the route itself plus [Authorize(Roles=...)] on the API.
  readonly navGroups: NavGroup[] = this.filterNavGroupsByRole(NAV_GROUPS);

  // Below the tablet breakpoint the rail is an off-canvas overlay (toggled
  // by the topbar hamburger) instead of a permanent column - 70px is a much
  // bigger bite out of a phone-width viewport than a desktop one.
  readonly isHandset = toSignal(
    this.breakpointObserver.observe([Breakpoints.Handset, Breakpoints.TabletPortrait]),
    { initialValue: { matches: false, breakpoints: {} } },
  );
  readonly mobileNavOpen = signal(false);

  // Which group's flyout panel is open (click-to-open/close, not
  // hover-to-preview - hover-only flyouts aren't reachable by keyboard and
  // are awkward on touch, and this is a business tool people use all day,
  // not a marketing site).
  readonly openGroupIndex = signal<number | null>(null);
  readonly openGroup = computed(() => {
    const index = this.openGroupIndex();
    return index === null ? null : this.navGroups[index];
  });

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

  // Which rail icon corresponds to the section the user is currently in -
  // stays highlighted regardless of whether its flyout is open.
  readonly activeGroupIndex = computed(() => {
    this.currentUrl();
    const url = this.router.url;
    return this.navGroups.findIndex((group) => group.items.some((item) => url.startsWith(item.path)));
  });

  // A page-specific title (set via PageTitleService, e.g. a vehicle's
  // registration number, "Edit Driver") wins when present; otherwise this
  // falls back to the matched nav item's generic section label.
  readonly breadcrumb = computed(() => {
    const specific = this.pageTitleService.title();
    if (specific) return specific;

    this.currentUrl();
    const url = this.router.url;
    const active = this.navGroups.flatMap((g) => g.items).find((item) => url.startsWith(item.path));
    return active?.label ?? 'Dashboard';
  });

  constructor() {
    // Close the flyout and the mobile rail overlay after navigating - both
    // would otherwise stay open on top of the page the user just picked.
    effect(() => {
      this.currentUrl();
      this.openGroupIndex.set(null);
      if (this.isHandset().matches) {
        this.mobileNavOpen.set(false);
      }
    });
  }

  @HostListener('document:keydown.escape')
  onEscape(): void {
    this.openGroupIndex.set(null);
    this.searchOpen.set(false);
  }

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: Event): void {
    if (this.searchOpen() && !this.elementRef.nativeElement.contains(event.target)) {
      this.searchOpen.set(false);
    }
  }

  navigateToResult(result: SearchResultModel): void {
    const buildRoute = SEARCH_RESULT_ROUTES[result.entityType];
    if (buildRoute) {
      this.router.navigate(buildRoute(result.entityId));
    }
    this.searchTerm.set('');
    this.searchOpen.set(false);
  }

  toggleMobileNav(): void {
    this.mobileNavOpen.update((v) => !v);
  }

  toggleGroup(index: number): void {
    this.openGroupIndex.update((current) => (current === index ? null : index));
  }

  closeGroup(): void {
    this.openGroupIndex.set(null);
  }

  toggleTheme(event: MouseEvent): void {
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    if (!document.startViewTransition || prefersReducedMotion) {
      this.themeService.toggle();
      return;
    }

    // Route transitions (see styles.scss) give .app-shell__main its own
    // view-transition-name so nav stays put during a page change. A theme
    // swap wants the opposite - one circular wipe across the *whole*
    // viewport - so main-content is dropped back into the root snapshot
    // for just this one transition, then restored once it's done.
    const mainEl = document.querySelector<HTMLElement>('.app-shell__main');
    mainEl?.style.setProperty('view-transition-name', 'none');

    const x = event.clientX;
    const y = event.clientY;
    const endRadius = Math.hypot(
      Math.max(x, window.innerWidth - x),
      Math.max(y, window.innerHeight - y)
    );

    const transition = document.startViewTransition(() => {
      this.themeService.toggle();
    });

    transition.ready.then(() => {
      document.documentElement.animate(
        {
          clipPath: [
            `circle(0px at ${x}px ${y}px)`,
            `circle(${endRadius}px at ${x}px ${y}px)`
          ],
          // Softens the growing edge into a gentle focus-pull instead of a
          // hard-edged circle - sharpens back to normal as it finishes.
          filter: ['blur(28px)', 'blur(0px)']
        },
        {
          duration: 950,
          easing: 'cubic-bezier(0.4, 0, 0.2, 1)',
          pseudoElement: '::view-transition-new(root)'
        }
      );
    });

    transition.finished.finally(() => {
      mainEl?.style.removeProperty('view-transition-name');
    });
  }

  logout(): void {
    // Login replaces this whole component (see app.routes.ts), so there's
    // no "after" to restore this on - it just disappears along with
    // everything else here. Dropping it avoids main-content fading out on
    // its own small route-change animation (styles.scss) on top of the
    // full-viewport blur dissolve this navigation gets (app.config.ts).
    document.querySelector<HTMLElement>('.app-shell__main')
      ?.style.setProperty('view-transition-name', 'none');

    this.authService.logout();
    sessionStorage.clear();
    this.router.navigate(['/login']);
  }

  private filterNavGroupsByRole(groups: NavGroup[]): NavGroup[] {
    // Reads directly off authService (not the `roles` field below) since
    // this runs as part of the `navGroups` field initializer, which - per
    // TS class field init order - executes before `roles` is assigned.
    const userRoles = this.authService.getRoles();

    return groups
      .map((group) => ({
        ...group,
        items: group.items.filter((item) => !item.roles || item.roles.some((role) => userRoles.includes(role))),
      }))
      .filter((group) => group.items.length > 0);
  }
}
