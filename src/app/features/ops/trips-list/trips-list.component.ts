import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { OpsService } from '../../../services/ops.service';
import { LookupService } from '../../../services/lookup.service';
import { TripModel } from '../../../models/ops.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createServerPagedListState } from '../../../shared/util/server-paged-list-state';

@Component({
  selector: 'app-trips-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, MatFormFieldModule, MatSelectModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './trips-list.component.html',
  styleUrl: './trips-list.component.scss',
})
export class TripsListComponent {
  private readonly opsService = inject(OpsService);
  private readonly lookupService = inject(LookupService);
  private readonly router = inject(Router);

  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly statusFilter = signal<number | null>(null);

  readonly columns = computed<DataTableColumn<TripModel>[]>(() => [
    { key: 'routeName', label: 'Route', sortable: true, cell: (row) => row.routeName },
    { key: 'ownershipType', label: 'Ownership', cell: (row) => row.ownershipType },
    { key: 'registrationNo', label: 'Vehicle', cell: (row) => row.registrationNo ?? row.hiredVehicleNo ?? '-' },
    { key: 'driverName', label: 'Driver', cell: (row) => row.driverName ?? row.hiredDriverName ?? '-' },
    { key: 'scheduledDeparture', label: 'Departure', sortable: true, cell: (row) => this.formatDateTime(row.scheduledDeparture) },
    { key: 'scheduledArrival', label: 'Arrival', cell: (row) => this.formatDateTime(row.scheduledArrival) },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
  ]);

  // statusFilter is a real server-side constraint (a query param the
  // backend already honours), separate from the data-table's free-text
  // search box, which only narrows the current page client-side - the two
  // compose because this closure re-reads statusFilter() on every load().
  readonly list = createServerPagedListState<TripModel>((pageNumber, pageSize) =>
    this.opsService.getTrips({ statusId: this.statusFilter() ?? undefined }, pageNumber, pageSize),
  );

  constructor() {
    this.lookupService.getStatusCodes('Trip').subscribe((statuses) => this.statusOptions.set(statuses));
    this.list.load();
  }

  onStatusFilterChange(statusId: number | null): void {
    this.statusFilter.set(statusId);
    this.list.pageIndex.set(0);
    this.list.load();
  }

  openTrip(row: TripModel): void {
    this.router.navigate(['/ops/trips', row.id]);
  }

  rowId = (row: TripModel): number => row.id;

  private formatDateTime(value: string): string {
    return new Date(value).toLocaleString('en-IN', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  }
}
