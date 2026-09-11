import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatTableModule } from '@angular/material/table';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { OpsService } from '../../../services/ops.service';
import { ToastService } from '../../../core/services/toast.service';
import { ShipmentModel } from '../../../models/ops.models';

@Component({
  selector: 'app-shipments-list',
  imports: [RouterLink, MatTableModule, MatButtonModule, MatIconModule, EmptyStateComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './shipments-list.component.html',
  styleUrl: './shipments-list.component.scss',
})
export class ShipmentsListComponent {
  readonly shipments = signal<ShipmentModel[]>([]);
  readonly loading = signal(true);
  readonly displayedColumns = ['customerName', 'originCityName', 'destinationCityName', 'shipmentDate', 'statusName'];

  constructor(
    private opsService: OpsService,
    private toast: ToastService,
  ) {
    this.opsService.getShipments({}).subscribe({
      next: (shipments) => {
        this.shipments.set(shipments);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
        this.toast.error('Failed to load shipments');
      },
    });
  }

  formatDate(value: string): string {
    return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
