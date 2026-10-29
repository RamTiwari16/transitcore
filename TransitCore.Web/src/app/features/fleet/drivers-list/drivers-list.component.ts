import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { FleetService } from '../../../services/fleet.service';
import { DriverModel } from '../../../models/fleet.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createClientPagedListState } from '../../../shared/util/client-paged-list-state';

@Component({
  selector: 'app-drivers-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, MatTooltipModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './drivers-list.component.html',
  styleUrl: './drivers-list.component.scss',
})
export class DriversListComponent {
  private readonly fleetService = inject(FleetService);
  private readonly router = inject(Router);

  readonly columns = computed<DataTableColumn<DriverModel>[]>(() => [
    { key: 'fullName', label: 'Name', sortable: true, cell: (row) => row.fullName },
    { key: 'phoneNo', label: 'Phone', cell: (row) => row.phoneNo ?? '-' },
    { key: 'email', label: 'Email', cell: (row) => row.email ?? '-' },
    { key: 'hireDate', label: 'Hire Date', cell: (row) => this.formatDate(row.hireDate) },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
  ]);

  // getDrivers() returns the whole list (backend doesn't paginate it) - see
  // client-paged-list-state.ts for why that makes full client-side
  // paging/sort/filter the right fit here, not a lesser substitute.
  readonly list = createClientPagedListState<DriverModel>(() => this.fleetService.getDrivers());

  constructor() {
    this.list.load();
  }

  rowId = (row: DriverModel): number => row.id;

  openDriver(row: DriverModel): void {
    this.router.navigate(['/fleet/drivers', row.id]);
  }

  private formatDate(value: string | null): string {
    if (!value) return '-';
    return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
