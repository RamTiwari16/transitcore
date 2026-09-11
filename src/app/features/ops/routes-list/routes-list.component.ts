import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { MatTableModule } from '@angular/material/table';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { OpsService } from '../../../services/ops.service';
import { ToastService } from '../../../core/services/toast.service';
import { RouteModel } from '../../../models/ops.models';

@Component({
  selector: 'app-routes-list',
  imports: [MatTableModule, EmptyStateComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './routes-list.component.html',
  styleUrl: './routes-list.component.scss',
})
export class RoutesListComponent {
  readonly routes = signal<RouteModel[]>([]);
  readonly loading = signal(true);
  readonly displayedColumns = ['name', 'originCityName', 'destinationCityName', 'distanceKm'];

  constructor(
    private opsService: OpsService,
    private toast: ToastService,
  ) {
    this.opsService.getRoutes().subscribe({
      next: (routes) => {
        this.routes.set(routes);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.toast.error('Failed to load routes');
      },
    });
  }
}
