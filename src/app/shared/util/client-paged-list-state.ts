import { computed, signal } from '@angular/core';
import { Observable } from 'rxjs';
import type { PageEvent } from '@angular/material/paginator';
import type { Sort } from '@angular/material/sort';
import { defaultMatchesFilter } from './list-filter';

/**
 * Shared state + fetch orchestration for list screens whose backend endpoint
 * returns the whole collection in one call (Drivers, Routes, Shipments,
 * Customers, Invoices all do this today - none of them paginate server-side
 * yet). Rather than leave these screens with no paging/sort/filter at all,
 * this does all three entirely client-side over the fetched array - which,
 * since the whole dataset is already in memory, is genuinely fully
 * functional (not a fake/partial version of it) at today's data volumes.
 * Swap a screen to createServerPagedListState instead once its backend
 * endpoint is paginated.
 */
export function createClientPagedListState<T>(
  fetchAll: () => Observable<T[]>,
  matchesFilter: (row: T, filterText: string) => boolean = defaultMatchesFilter,
) {
  const allRows = signal<T[]>([]);
  const loading = signal(true);
  const pageIndex = signal(0);
  const pageSize = signal(10);
  const filterText = signal('');
  const sortActive = signal('');
  const sortDirection = signal<'asc' | 'desc' | ''>('');

  const filteredRows = computed(() => {
    const text = filterText().trim().toLowerCase();
    const rows = allRows();
    return text ? rows.filter((row) => matchesFilter(row, text)) : rows;
  });

  const sortedRows = computed(() => {
    const active = sortActive();
    const direction = sortDirection();
    const rows = filteredRows();
    if (!active || !direction) return rows;

    const sorted = [...rows].sort((a, b) => {
      const av = (a as Record<string, unknown>)[active];
      const bv = (b as Record<string, unknown>)[active];
      if (av == null) return bv == null ? 0 : -1;
      if (bv == null) return 1;
      return typeof av === 'number' && typeof bv === 'number'
        ? av - bv
        : String(av).localeCompare(String(bv));
    });
    return direction === 'desc' ? sorted.reverse() : sorted;
  });

  const totalCount = computed(() => sortedRows().length);

  const rows = computed(() => {
    const start = pageIndex() * pageSize();
    return sortedRows().slice(start, start + pageSize());
  });

  function load(): void {
    loading.set(true);
    fetchAll().subscribe({
      next: (result) => {
        allRows.set(result);
        loading.set(false);
      },
      error: () => {
        allRows.set([]);
        loading.set(false);
      },
    });
  }

  function onPage(event: PageEvent): void {
    pageIndex.set(event.pageIndex);
    pageSize.set(event.pageSize);
  }

  function onSort(sort: Sort): void {
    sortActive.set(sort.direction ? sort.active : '');
    sortDirection.set(sort.direction);
    pageIndex.set(0);
  }

  function onFilter(text: string): void {
    filterText.set(text);
    pageIndex.set(0);
  }

  return { rows, totalCount, loading, pageIndex, pageSize, filterText, load, onPage, onSort, onFilter };
}
