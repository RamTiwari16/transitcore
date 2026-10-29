import { computed, signal } from '@angular/core';
import { Observable } from 'rxjs';
import type { PageEvent } from '@angular/material/paginator';
import type { PagedResult } from '../../models/paged-result';
import { defaultMatchesFilter } from './list-filter';

/**
 * Shared state + fetch orchestration for list screens backed by an endpoint
 * that already does real server-side paging (returns PagedResult<T>) -
 * currently just Vehicles and Trips. Replaces the identical rows/totalCount/
 * loading/pageIndex/pageSize signals + load()/onPage() that used to be
 * hand-copied into every list component.
 *
 * Filter here only searches the current page's already-loaded rows: these
 * backend endpoints don't accept a search query param yet, so true
 * server-side filtering needs that added first. Sort is likewise UI-only
 * until the backend accepts an @OrderBy param - `onSort` is exposed so a
 * screen's template can still wire it up (matching the existing no-op sort
 * handlers already in this codebase) without silently claiming it works.
 */
export function createServerPagedListState<T>(
  fetchPage: (pageNumber: number, pageSize: number) => Observable<PagedResult<T>>,
  matchesFilter: (row: T, filterText: string) => boolean = defaultMatchesFilter,
) {
  const allRows = signal<T[]>([]);
  const totalCount = signal(0);
  const loading = signal(true);
  const pageIndex = signal(0);
  const pageSize = signal(10);
  const filterText = signal('');

  const rows = computed(() => {
    const text = filterText().trim().toLowerCase();
    if (!text) return allRows();
    return allRows().filter((row) => matchesFilter(row, text));
  });

  function load(): void {
    loading.set(true);
    fetchPage(pageIndex() + 1, pageSize()).subscribe({
      next: (result) => {
        allRows.set(result.items);
        totalCount.set(result.totalCount);
        loading.set(false);
      },
      error: () => {
        // errorInterceptor already toasted this - just stop the spinner and
        // drop stale rows rather than leaving the previous page showing.
        allRows.set([]);
        totalCount.set(0);
        loading.set(false);
      },
    });
  }

  function onPage(event: PageEvent): void {
    pageIndex.set(event.pageIndex);
    pageSize.set(event.pageSize);
    load();
  }

  function onFilter(text: string): void {
    filterText.set(text);
  }

  return { rows, totalCount, loading, pageIndex, pageSize, filterText, load, onPage, onFilter };
}
