import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { VendorService } from '../../../services/vendor.service';
import { VendorModel } from '../../../models/vendor.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createClientPagedListState } from '../../../shared/util/client-paged-list-state';

@Component({
  selector: 'app-vendors-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, MatTooltipModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './vendors-list.component.html',
  styleUrl: './vendors-list.component.scss',
})
export class VendorsListComponent {
  private readonly vendorService = inject(VendorService);
  private readonly router = inject(Router);

  readonly columns = computed<DataTableColumn<VendorModel>[]>(() => [
    { key: 'code', label: 'Code', sortable: true, cell: (row) => row.code },
    { key: 'name', label: 'Name', sortable: true, cell: (row) => row.name },
    { key: 'contactName', label: 'Contact', cell: (row) => row.contactName ?? '-' },
    { key: 'contactPhone', label: 'Phone', cell: (row) => row.contactPhone ?? '-' },
    { key: 'isActive', label: 'Active', cell: (row) => (row.isActive ? 'Yes' : 'No') },
  ]);

  readonly list = createClientPagedListState<VendorModel>(() => this.vendorService.getVendors(false));

  constructor() {
    this.list.load();
  }

  rowId = (row: VendorModel): number => row.id;

  openVendor(row: VendorModel): void {
    this.router.navigate(['/vendors', row.id]);
  }
}
