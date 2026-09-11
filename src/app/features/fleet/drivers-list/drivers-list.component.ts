import { ChangeDetectionStrategy, Component, computed, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { PageEvent } from '@angular/material/paginator';
import { Sort } from '@angular/material/sort';
import { FleetService } from '../../../services/fleet.service';
import { ToastService } from '../../../core/services/toast.service';
import { DriverModel } from '../../../models/fleet.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';

@Component({
  selector: 'app-drivers-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './drivers-list.component.html',
  styleUrl: './drivers-list.component.scss',
})
export class DriversListComponent {
  private readonly allDrivers = signal<DriverModel[]>([]);
  readonly loading = signal(true);
  readonly pageIndex = signal(0);
  readonly pageSize = signal(10);

  readonly totalCount = computed(() => this.allDrivers().length);
  readonly rows = computed(() => {
    const start = this.pageIndex() * this.pageSize();
    return this.allDrivers().slice(start, start + this.pageSize());
  });

  readonly columns = computed<DataTableColumn<DriverModel>[]>(() => [
    { key: 'fullName', label: 'Name', sortable: true, cell: (row) => row.fullName },
    { key: 'phoneNo', label: 'Phone', cell: (row) => row.phoneNo ?? '-' },
    { key: 'email', label: 'Email', cell: (row) => row.email ?? '-' },
    { key: 'hireDate', label: 'Hire Date', cell: (row) => this.formatDate(row.hireDate) },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
  ]);

  constructor(
    private fleetService: FleetService,
    private toast: ToastService,
  ) {
    this.fleetService.getDrivers().subscribe({
      next: (drivers) => {
        this.allDrivers.set(drivers);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.toast.error('Failed to load drivers');
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

  rowId = (row: DriverModel): number => row.id;

  private formatDate(value: string | null): string {
    if (!value) return '-';
    return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
