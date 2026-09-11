import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { MatTableModule } from '@angular/material/table';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { FleetService } from '../../../services/fleet.service';
import { ToastService } from '../../../core/services/toast.service';
import { DriverModel } from '../../../models/fleet.models';

@Component({
  selector: 'app-drivers-list',
  imports: [MatTableModule, EmptyStateComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './drivers-list.component.html',
  styleUrl: './drivers-list.component.scss',
})
export class DriversListComponent {
  readonly drivers = signal<DriverModel[]>([]);
  readonly loading = signal(true);
  readonly displayedColumns = ['fullName', 'phoneNo', 'email', 'hireDate', 'statusName'];

  constructor(
    private fleetService: FleetService,
    private toast: ToastService,
  ) {
    this.fleetService.getDrivers().subscribe({
      next: (drivers) => {
        this.drivers.set(drivers);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.toast.error('Failed to load drivers');
      },
    });
  }

  formatDate(value: string | null): string {
    if (!value) return '-';
    return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
