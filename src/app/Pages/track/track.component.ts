import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { OpsService } from '../../services/ops.service';
import { ShipmentTrackingModel } from '../../models/ops.models';

interface TrackFormModel {
  trackingNo: FormControl<string>;
}

// Public, unauthenticated page - deliberately outside the authGuard'd
// Layout route tree in app.routes.ts, backed by the equally-public
// /api/v1/public/track endpoint (PublicController, no [Authorize]).
@Component({
  selector: 'app-track',
  imports: [ReactiveFormsModule, MatButtonModule, MatFormFieldModule, MatIconModule, MatInputModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './track.component.html',
  styleUrl: './track.component.scss',
})
export class TrackComponent {
  private readonly opsService = inject(OpsService);
  private readonly route = inject(ActivatedRoute);

  readonly loading = signal(false);
  readonly searched = signal(false);
  readonly result = signal<ShipmentTrackingModel | null>(null);
  readonly notFound = signal(false);

  readonly form = new FormGroup<TrackFormModel>({
    trackingNo: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });

  constructor() {
    const fromUrl = this.route.snapshot.paramMap.get('trackingNo');
    if (fromUrl) {
      this.form.patchValue({ trackingNo: fromUrl });
      this.search();
    }
  }

  search(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const trackingNo = this.form.getRawValue().trackingNo.trim();
    this.loading.set(true);
    this.notFound.set(false);

    this.opsService.trackShipment(trackingNo).subscribe({
      next: (result) => {
        this.result.set(result);
        this.searched.set(true);
        this.loading.set(false);
      },
      error: () => {
        this.result.set(null);
        this.notFound.set(true);
        this.searched.set(true);
        this.loading.set(false);
      },
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
