import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatTabsModule } from '@angular/material/tabs';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatSelectModule } from '@angular/material/select';
import { OpsService } from '../../../services/ops.service';
import { LookupService } from '../../../services/lookup.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { ToastService } from '../../../core/services/toast.service';
import { TripDetailModel } from '../../../models/ops.models';
import { StatusCodeModel } from '../../../models/lookup.models';

@Component({
  selector: 'app-trip-detail',
  imports: [RouterLink, MatTabsModule, MatButtonModule, MatIconModule, MatFormFieldModule, MatSelectModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './trip-detail.component.html',
  styleUrl: './trip-detail.component.scss',
})
export class TripDetailComponent {
  readonly trip = signal<TripDetailModel | null>(null);
  readonly loading = signal(true);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly pendingStatusId = signal<number | null>(null);

  private readonly route = inject(ActivatedRoute);
  private readonly tripId = Number(this.route.snapshot.paramMap.get('id'));

  constructor(
    private opsService: OpsService,
    private lookupService: LookupService,
    private confirmDialog: ConfirmDialogService,
    private toast: ToastService,
  ) {
    this.lookupService.getStatusCodes('Trip').subscribe((s) => this.statusOptions.set(s));
    this.load();
  }

  private load(): void {
    this.loading.set(true);
    this.opsService.getTripById(this.tripId).subscribe({
      next: (trip) => {
        this.trip.set(trip);
        this.pendingStatusId.set(trip.statusId);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  applyStatusChange(): void {
    const trip = this.trip();
    const newStatusId = this.pendingStatusId();
    if (!trip || newStatusId === null || newStatusId === trip.statusId) {
      return;
    }

    const newStatusName = this.statusOptions().find((s) => s.id === newStatusId)?.name ?? 'selected status';

    this.confirmDialog
      .confirm({
        title: 'Update trip status?',
        message: `Change this trip's status to "${newStatusName}"?`,
        confirmLabel: 'Update status',
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;

        this.opsService.updateTripStatus({ tripId: trip.id, statusId: newStatusId }).subscribe({
          next: () => {
            this.toast.success('Trip status updated');
            this.load();
          },
          error: (err) => this.toast.error(err?.error?.message || 'Failed to update trip status'),
        });
      });
  }

  formatDateTime(value: string | null): string {
    if (!value) return '-';
    return new Date(value).toLocaleString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }
}
