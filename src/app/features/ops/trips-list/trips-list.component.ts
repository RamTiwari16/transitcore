import { ChangeDetectionStrategy, Component, computed, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { PageEvent } from '@angular/material/paginator';
import { Sort } from '@angular/material/sort';
import { OpsService } from '../../../services/ops.service';
import { LookupService } from '../../../services/lookup.service';
import { TripModel } from '../../../models/ops.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';

@Component({
  selector: 'app-trips-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, MatFormFieldModule, MatSelectModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './trips-list.component.html',
  styleUrl: './trips-list.component.scss',
})
export class TripsListComponent {
  readonly rows = signal<TripModel[]>([]);
  readonly totalCount = signal(0);
  readonly loading = signal(true);
  readonly pageIndex = signal(0);
  readonly pageSize = signal(10);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly statusFilter = signal<number | null>(null);

  readonly columns = computed<DataTableColumn<TripModel>[]>(() => [
    { key: 'routeName', label: 'Route', sortable: true, cell: (row) => row.routeName },
    { key: 'registrationNo', label: 'Vehicle', cell: (row) => row.registrationNo },
    { key: 'driverName', label: 'Driver', cell: (row) => row.driverName },
    { key: 'scheduledDeparture', label: 'Departure', sortable: true, cell: (row) => this.formatDateTime(row.scheduledDeparture) },
    { key: 'scheduledArrival', label: 'Arrival', cell: (row) => this.formatDateTime(row.scheduledArrival) },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
  ]);

  constructor(
    private opsService: OpsService,
    private lookupService: LookupService,
    private router: Router,
  ) {
    this.lookupService.getStatusCodes('Trip').subscribe((statuses) => this.statusOptions.set(statuses));
    this.load();
  }

  private load(): void {
    this.loading.set(true);
    this.opsService
      .getTrips({ statusId: this.statusFilter() ?? undefined }, this.pageIndex() + 1, this.pageSize())
      .subscribe({
        next: (result) => {
          this.rows.set(result.items);
          this.totalCount.set(result.totalCount);
          this.loading.set(false);
        },
        error: () => this.loading.set(false),
      });
  }

  onStatusFilterChange(statusId: number | null): void {
    this.statusFilter.set(statusId);
    this.pageIndex.set(0);
    this.load();
  }

  onPage(event: PageEvent): void {
    this.pageIndex.set(event.pageIndex);
    this.pageSize.set(event.pageSize);
    this.load();
  }

  onSort(_sort: Sort): void {
    // Server-side sorting isn't implemented for this endpoint yet.
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
