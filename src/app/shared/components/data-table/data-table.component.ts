import { ChangeDetectionStrategy, Component, TemplateRef, computed, contentChild, input, output, signal } from '@angular/core';
import { NgTemplateOutlet } from '@angular/common';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { MatPaginatorModule, PageEvent } from '@angular/material/paginator';
import { MatSortModule, Sort } from '@angular/material/sort';
import { MatTableModule } from '@angular/material/table';
import { MatTooltipModule } from '@angular/material/tooltip';
import { EmptyStateComponent } from '../empty-state/empty-state.component';

export interface DataTableColumn<T> {
  key: string;
  label: string;
  sortable?: boolean;
  hiddenByDefault?: boolean;
  cell: (row: T) => string;
}

/**
 * Generic, reusable data table for server-paginated/server-sorted lists.
 * The host page owns fetching: it passes the current page's rows plus
 * totalCount, and reacts to (pageChange)/(sortChange) by refetching.
 * CSV export covers only the currently loaded page (server-side export of
 * every filtered row would need a dedicated backend export endpoint - not
 * built yet).
 */
@Component({
  selector: 'app-data-table',
  imports: [
    NgTemplateOutlet,
    MatTableModule,
    MatPaginatorModule,
    MatSortModule,
    MatCheckboxModule,
    MatButtonModule,
    MatIconModule,
    MatMenuModule,
    MatTooltipModule,
    EmptyStateComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './data-table.component.html',
  styleUrl: './data-table.component.scss',
})
export class DataTableComponent<T> {
  readonly columns = input.required<DataTableColumn<T>[]>();
  readonly rows = input<T[]>([]);
  readonly totalCount = input(0);
  readonly loading = input(false);
  readonly pageSize = input(10);
  readonly pageSizeOptions = input<number[]>([10, 25, 50]);
  readonly pageIndex = input(0);
  readonly selectable = input(false);
  readonly rowId = input<(row: T) => string | number>((row) => JSON.stringify(row));
  readonly emptyTitle = input('No records found');
  readonly emptyDescription = input<string>();

  // Optional per-row action buttons (e.g. download/delete), projected via
  // `<ng-template #rowActions let-row>...</ng-template>` in the host's
  // markup. Purely additive - lists that don't provide one are unaffected.
  readonly rowActionsTemplate = contentChild<TemplateRef<{ $implicit: T }>>('rowActions');

  readonly pageChange = output<PageEvent>();
  readonly sortChange = output<Sort>();
  readonly selectionChange = output<T[]>();
  readonly exportCsvRequested = output<void>();
  readonly rowClick = output<T>();

  private readonly hiddenColumnKeys = signal<Set<string>>(new Set());
  private readonly selectedIds = signal<Set<string | number>>(new Set());

  readonly visibleColumns = computed(() =>
    this.columns().filter((c) => !this.hiddenColumnKeys().has(c.key)),
  );

  readonly displayedColumnKeys = computed(() => {
    const keys = this.visibleColumns().map((c) => c.key);
    const withSelect = this.selectable() ? ['__select', ...keys] : keys;
    return this.rowActionsTemplate() ? [...withSelect, '__actions'] : withSelect;
  });

  readonly selectedCount = computed(() => this.selectedIds().size);

  readonly allOnPageSelected = computed(() => {
    const rows = this.rows();
    if (rows.length === 0) return false;
    return rows.every((row) => this.selectedIds().has(this.rowId()(row)));
  });

  isColumnVisible(key: string): boolean {
    return !this.hiddenColumnKeys().has(key);
  }

  toggleColumn(key: string): void {
    const next = new Set(this.hiddenColumnKeys());
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    this.hiddenColumnKeys.set(next);
  }

  isRowSelected(row: T): boolean {
    return this.selectedIds().has(this.rowId()(row));
  }

  toggleRow(row: T): void {
    const id = this.rowId()(row);
    const next = new Set(this.selectedIds());
    if (next.has(id)) {
      next.delete(id);
    } else {
      next.add(id);
    }
    this.selectedIds.set(next);
    this.emitSelection();
  }

  toggleAllOnPage(): void {
    const next = new Set(this.selectedIds());
    const rows = this.rows();

    if (this.allOnPageSelected()) {
      rows.forEach((row) => next.delete(this.rowId()(row)));
    } else {
      rows.forEach((row) => next.add(this.rowId()(row)));
    }

    this.selectedIds.set(next);
    this.emitSelection();
  }

  clearSelection(): void {
    this.selectedIds.set(new Set());
    this.emitSelection();
  }

  onPage(event: PageEvent): void {
    this.pageChange.emit(event);
  }

  onRowClick(row: T): void {
    this.rowClick.emit(row);
  }

  onSort(sort: Sort): void {
    this.sortChange.emit(sort);
  }

  exportCsv(): void {
    const columns = this.visibleColumns();
    const header = columns.map((c) => escapeCsvValue(c.label)).join(',');
    const lines = this.rows().map((row) =>
      columns.map((c) => escapeCsvValue(c.cell(row))).join(','),
    );

    const csv = [header, ...lines].join('\r\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'export.csv';
    link.click();
    URL.revokeObjectURL(url);

    this.exportCsvRequested.emit();
  }

  private emitSelection(): void {
    const ids = this.selectedIds();
    const selected = this.rows().filter((row) => ids.has(this.rowId()(row)));
    this.selectionChange.emit(selected);
  }
}

function escapeCsvValue(value: string): string {
  if (value.includes(',') || value.includes('"') || value.includes('\n')) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}
