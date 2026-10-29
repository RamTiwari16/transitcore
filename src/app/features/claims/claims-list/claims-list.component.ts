import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { ClaimService } from '../../../services/claim.service';
import { LookupService } from '../../../services/lookup.service';
import { ClaimModel } from '../../../models/claim.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createServerPagedListState } from '../../../shared/util/server-paged-list-state';

@Component({
  selector: 'app-claims-list',
  imports: [MatFormFieldModule, MatSelectModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './claims-list.component.html',
  styleUrl: './claims-list.component.scss',
})
export class ClaimsListComponent {
  private readonly claimService = inject(ClaimService);
  private readonly lookupService = inject(LookupService);
  private readonly router = inject(Router);

  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly statusFilter = signal<number | null>(null);

  readonly columns = computed<DataTableColumn<ClaimModel>[]>(() => [
    { key: 'trackingNo', label: 'Shipment', sortable: true, cell: (row) => row.trackingNo },
    { key: 'claimantName', label: 'Claimant', cell: (row) => row.claimantName },
    { key: 'amountClaimed', label: 'Amount Claimed', cell: (row) => this.formatCurrency(row.amountClaimed) },
    { key: 'statusName', label: 'Status', cell: (row) => row.statusName },
    {
      key: 'settledAmount',
      label: 'Settled',
      cell: (row) => (row.settledAmount !== null ? `${this.formatCurrency(row.settledAmount)} (${row.settlementMethod})` : '-'),
    },
    { key: 'createdAt', label: 'Raised', sortable: true, cell: (row) => this.formatDate(row.createdAt) },
  ]);

  readonly list = createServerPagedListState<ClaimModel>((pageNumber, pageSize) =>
    this.claimService.getClaims({ statusId: this.statusFilter() ?? undefined }, pageNumber, pageSize),
  );

  constructor() {
    this.lookupService.getStatusCodes('Claim').subscribe((statuses) => this.statusOptions.set(statuses));
    this.list.load();
  }

  onStatusFilterChange(statusId: number | null): void {
    this.statusFilter.set(statusId);
    this.list.pageIndex.set(0);
    this.list.load();
  }

  openClaim(row: ClaimModel): void {
    this.router.navigate(['/claims', row.id]);
  }

  rowId = (row: ClaimModel): number => row.id;

  private formatDate(value: string): string {
    return new Date(value).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  private formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
  }
}
