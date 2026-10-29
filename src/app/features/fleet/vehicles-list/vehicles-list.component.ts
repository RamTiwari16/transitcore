import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { FleetService } from '../../../services/fleet.service';
import { VehicleModel } from '../../../models/fleet.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createServerPagedListState } from '../../../shared/util/server-paged-list-state';

@Component({
  selector: 'app-vehicles-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, MatTooltipModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './vehicles-list.component.html',
  styleUrl: './vehicles-list.component.scss',
})
export class VehiclesListComponent {
  private readonly fleetService = inject(FleetService);
  private readonly router = inject(Router);

  readonly columns = computed<DataTableColumn<VehicleModel>[]>(() => [
    { key: 'registrationNo', label: 'Registration No', sortable: true, cell: (row) => row.registrationNo },
    { key: 'vehicleTypeName', label: 'Type', cell: (row) => row.vehicleTypeName },
    { key: 'makeModel', label: 'Make / Model', cell: (row) => [row.make, row.model].filter(Boolean).join(' ') || '-' },
    { key: 'capacityKg', label: 'Capacity (kg)', sortable: true, cell: (row) => row.capacityKg.toLocaleString() },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
  ]);

  readonly list = createServerPagedListState<VehicleModel>((pageNumber, pageSize) =>
    this.fleetService.getVehicles(pageNumber, pageSize),
  );

  constructor() {
    this.list.load();
  }

  rowId = (row: VehicleModel): number => row.id;

  openVehicle(row: VehicleModel): void {
    this.router.navigate(['/fleet/vehicles', row.id]);
  }
}
