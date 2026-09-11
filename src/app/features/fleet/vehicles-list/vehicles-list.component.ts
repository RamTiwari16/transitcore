import { ChangeDetectionStrategy, Component, computed, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { PageEvent } from '@angular/material/paginator';
import { Sort } from '@angular/material/sort';
import { FleetService } from '../../../services/fleet.service';
import { VehicleModel } from '../../../models/fleet.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';

@Component({
  selector: 'app-vehicles-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './vehicles-list.component.html',
  styleUrl: './vehicles-list.component.scss',
})
export class VehiclesListComponent {
  readonly rows = signal<VehicleModel[]>([]);
  readonly totalCount = signal(0);
  readonly loading = signal(true);
  readonly pageIndex = signal(0);
  readonly pageSize = signal(10);

  readonly columns = computed<DataTableColumn<VehicleModel>[]>(() => [
    { key: 'registrationNo', label: 'Registration No', sortable: true, cell: (row) => row.registrationNo },
    { key: 'vehicleTypeName', label: 'Type', cell: (row) => row.vehicleTypeName },
    { key: 'makeModel', label: 'Make / Model', cell: (row) => [row.make, row.model].filter(Boolean).join(' ') || '-' },
    { key: 'capacityKg', label: 'Capacity (kg)', sortable: true, cell: (row) => row.capacityKg.toLocaleString() },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
  ]);

  constructor(private fleetService: FleetService) {
    this.load();
  }

  private load(): void {
    this.loading.set(true);
    this.fleetService.getVehicles(this.pageIndex() + 1, this.pageSize()).subscribe({
      next: (result) => {
        this.rows.set(result.items);
        this.totalCount.set(result.totalCount);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  onPage(event: PageEvent): void {
    this.pageIndex.set(event.pageIndex);
    this.pageSize.set(event.pageSize);
    this.load();
  }

  onSort(_sort: Sort): void {
    // Server-side sorting isn't implemented for this endpoint yet - the
    // table still emits the event so it can be wired up without touching
    // the template once fleet.usp_GetVehicles supports an @OrderBy param.
  }

  rowId = (row: VehicleModel): number => row.id;
}
