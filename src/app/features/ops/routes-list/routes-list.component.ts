import { ChangeDetectionStrategy, Component, computed, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { PageEvent } from '@angular/material/paginator';
import { Sort } from '@angular/material/sort';
import { OpsService } from '../../../services/ops.service';
import { ToastService } from '../../../core/services/toast.service';
import { RouteModel } from '../../../models/ops.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';

@Component({
  selector: 'app-routes-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './routes-list.component.html',
  styleUrl: './routes-list.component.scss',
})
export class RoutesListComponent {
  private readonly allRoutes = signal<RouteModel[]>([]);
  readonly loading = signal(true);
  readonly pageIndex = signal(0);
  readonly pageSize = signal(10);

  readonly totalCount = computed(() => this.allRoutes().length);
  readonly rows = computed(() => {
    const start = this.pageIndex() * this.pageSize();
    return this.allRoutes().slice(start, start + this.pageSize());
  });

  readonly columns = computed<DataTableColumn<RouteModel>[]>(() => [
    { key: 'name', label: 'Route', sortable: true, cell: (row) => row.name },
    { key: 'originCityName', label: 'Origin', cell: (row) => row.originCityName },
    { key: 'destinationCityName', label: 'Destination', cell: (row) => row.destinationCityName },
    { key: 'distanceKm', label: 'Distance (km)', cell: (row) => row.distanceKm?.toLocaleString() ?? '-' },
  ]);

  constructor(
    private opsService: OpsService,
    private toast: ToastService,
  ) {
    this.opsService.getRoutes().subscribe({
      next: (routes) => {
        this.allRoutes.set(routes);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.toast.error('Failed to load routes');
      },
    });
  }

  onPage(event: PageEvent): void {
    this.pageIndex.set(event.pageIndex);
    this.pageSize.set(event.pageSize);
  }

  onSort(_sort: Sort): void {
    // Client-side pagination only for now - see onSort comment on
    // VehiclesListComponent for the server-side-sort follow-up note.
  }

  rowId = (row: RouteModel): number => row.id;
}
