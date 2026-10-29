import { Injectable, signal } from '@angular/core';

/**
 * Lets a page report a specific title (a vehicle's registration number, an
 * invoice number, "Edit Driver") for the topbar to show, instead of every
 * page carrying its own duplicate <h1> alongside the topbar's generic
 * section name (see layout.ts's `breadcrumb`, which falls back to the
 * matched nav item's label when nothing here is set).
 *
 * Callers MUST clear their title on destroy (`titleService.setTitle(null)`
 * in a DestroyRef.onDestroy callback) - otherwise a specific title lingers
 * into whatever page is navigated to next, right up until that next page
 * sets its own (or forever, if it doesn't set one at all).
 */
@Injectable({ providedIn: 'root' })
export class PageTitleService {
  readonly title = signal<string | null>(null);

  setTitle(title: string | null): void {
    this.title.set(title);
  }
}
