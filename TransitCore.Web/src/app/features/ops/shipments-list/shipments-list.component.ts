import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { OpsService } from '../../../services/ops.service';
import { ShipmentModel } from '../../../models/ops.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createClientPagedListState } from '../../../shared/util/client-paged-list-state';

@Component({
  selector: 'app-shipments-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, MatTooltipModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './shipments-list.component.html',
  styleUrl: './shipments-list.component.scss',
})
export class ShipmentsListComponent {
  private readonly opsService = inject(OpsService);

  readonly columns = computed<DataTableColumn<ShipmentModel>[]>(() => [
    { key: 'trackingNo', label: 'Tracking No', sortable: true, cell: (row) => row.trackingNo ?? '-' },
    { key: 'customerName', label: 'Customer', sortable: true, cell: (row) => row.customerName },
    { key: 'originCityName', label: 'Origin', cell: (row) => row.originCityName },
    { key: 'destinationCityName', label: 'Destination', cell: (row) => row.destinationCityName },
    { key: 'shipmentDate', label: 'Date', sortable: true, cell: (row) => this.formatDate(row.shipmentDate) },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
  ]);

  readonly list = createClientPagedListState<ShipmentModel>(() => this.opsService.getShipments({}));

  constructor() {
    this.list.load();
  }

  rowId = (row: ShipmentModel): number => row.id;

  private formatDate(value: string): string {
    return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }
}
