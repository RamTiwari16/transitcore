import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { OpsService } from '../../../services/ops.service';
import { RouteModel } from '../../../models/ops.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createClientPagedListState } from '../../../shared/util/client-paged-list-state';

@Component({
  selector: 'app-routes-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, MatTooltipModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './routes-list.component.html',
  styleUrl: './routes-list.component.scss',
})
export class RoutesListComponent {
  private readonly opsService = inject(OpsService);

  readonly columns = computed<DataTableColumn<RouteModel>[]>(() => [
    { key: 'name', label: 'Route', sortable: true, cell: (row) => row.name },
    { key: 'originCityName', label: 'Origin', cell: (row) => row.originCityName },
    { key: 'destinationCityName', label: 'Destination', cell: (row) => row.destinationCityName },
    { key: 'distanceKm', label: 'Distance (km)', cell: (row) => row.distanceKm?.toLocaleString() ?? '-' },
  ]);

  readonly list = createClientPagedListState<RouteModel>(() => this.opsService.getRoutes());

  constructor() {
    this.list.load();
  }

  rowId = (row: RouteModel): number => row.id;
}
