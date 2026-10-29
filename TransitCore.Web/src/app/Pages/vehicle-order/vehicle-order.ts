import { ChangeDetectionStrategy, Component, computed, signal } from '@angular/core';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTableModule } from '@angular/material/table';
import { MatPaginatorModule, PageEvent } from '@angular/material/paginator';
import { VehicleOrderRow, VehicleOrderService } from '../../services/vehicle-order-service';
import { EmptyStateComponent } from '../../shared/components/empty-state/empty-state.component';
import { toLocalIsoDate } from '../../shared/util/date';

@Component({
  selector: 'app-vehicle-order',
  imports: [
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule,
    MatIconModule,
    MatTableModule,
    MatPaginatorModule,
    EmptyStateComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './vehicle-order.html',
  styleUrl: './vehicle-order.scss',
})
export class VehicleOrder {
  readonly fromDate = signal(this.today());
  readonly toDate = signal(this.today());
  readonly isLoading = signal(false);
  readonly errorMsg = signal('');
  readonly searched = signal(false);
  readonly allData = signal<VehicleOrderRow[]>([]);
  readonly searchTerm = signal('');
  readonly pageIndex = signal(0);
  readonly pageSize = signal(10);
  readonly displayedColumns = ['index', 'orderNo', 'vehicleNo', 'uploadDate', 'createdByEmail'];

  readonly filteredData = computed(() => {
    const term = this.searchTerm().toLowerCase().trim();
    if (!term) return this.allData();

    return this.allData().filter(
      (row) => row.vehicleNo?.toLowerCase().includes(term) || row.orderNo?.toLowerCase().includes(term),
    );
  });

  readonly pagedData = computed(() => {
    const start = this.pageIndex() * this.pageSize();
    return this.filteredData().slice(start, start + this.pageSize());
  });

  constructor(private service: VehicleOrderService) {}

  private today(): string {
    return toLocalIsoDate();
  }

  search(): void {
    if (!this.fromDate() || !this.toDate()) {
      this.errorMsg.set('Please select both From and To dates.');
      return;
    }

    this.isLoading.set(true);
    this.errorMsg.set('');
    this.searched.set(false);

    this.service.getByDateRange({ fromDate: this.fromDate(), toDate: this.toDate() }).subscribe({
      next: (res) => {
        this.isLoading.set(false);
        this.searched.set(true);
        this.allData.set(res.data ?? []);
        this.searchTerm.set('');
        this.pageIndex.set(0);
      },
      error: (err) => {
        this.isLoading.set(false);
        this.searched.set(true);
        this.errorMsg.set(err?.error?.message || 'Failed to fetch data. Please try again.');
      },
    });
  }

  onSearchTermChange(value: string): void {
    this.searchTerm.set(value);
    this.pageIndex.set(0);
  }

  onPage(event: PageEvent): void {
    this.pageIndex.set(event.pageIndex);
    this.pageSize.set(event.pageSize);
  }

  formatDate(date: string): string {
    if (!date) return '-';
    return new Date(date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
