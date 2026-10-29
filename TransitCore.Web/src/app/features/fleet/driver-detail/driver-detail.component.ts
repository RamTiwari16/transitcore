import { ChangeDetectionStrategy, Component, DestroyRef, effect, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatTabsModule } from '@angular/material/tabs';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatTooltipModule } from '@angular/material/tooltip';
import { FleetService } from '../../../services/fleet.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import {
  DriverDetailModel,
  DriverLicenseModel,
  DriverPerformanceModel,
  DriverSettlementModel,
} from '../../../models/fleet.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';

interface LicenseFormModel {
  licenseNo: FormControl<string>;
  licenseType: FormControl<string>;
  issuedDate: FormControl<string>;
  expiryDate: FormControl<string>;
}

const EXPIRY_WARNING_DAYS = 30;

function daysUntil(dateStr: string): number {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(dateStr);
  return Math.round((target.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
}

@Component({
  selector: 'app-driver-detail',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatTabsModule,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule,
    MatTooltipModule,
    EmptyStateComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './driver-detail.component.html',
  styleUrl: './driver-detail.component.scss',
})
export class DriverDetailComponent {
  private readonly fleetService = inject(FleetService);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly toast = inject(ToastService);
  private readonly route = inject(ActivatedRoute);
  private readonly pageTitleService = inject(PageTitleService);
  private readonly driverId = Number(this.route.snapshot.paramMap.get('id'));

  readonly driver = signal<DriverDetailModel | null>(null);
  readonly loading = signal(true);

  readonly licenses = signal<DriverLicenseModel[]>([]);
  readonly savingLicense = signal(false);

  readonly performance = signal<DriverPerformanceModel | null>(null);
  readonly performanceLoading = signal(true);

  readonly settlement = signal<DriverSettlementModel | null>(null);
  readonly settlementLoading = signal(true);

  readonly licenseForm = new FormGroup<LicenseFormModel>({
    licenseNo: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    licenseType: new FormControl('', { nonNullable: true }),
    issuedDate: new FormControl('', { nonNullable: true }),
    expiryDate: new FormControl('', { nonNullable: true }),
  });

  constructor() {
    effect(() => this.pageTitleService.setTitle(this.driver()?.fullName ?? null));
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.fleetService.getDriverById(this.driverId).subscribe({
      next: (driver) => {
        this.driver.set(driver);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
    this.loadLicenses();

    this.fleetService.getDriverPerformance(this.driverId).subscribe({
      next: (performance) => {
        this.performance.set(performance);
        this.performanceLoading.set(false);
      },
      error: () => this.performanceLoading.set(false),
    });

    this.fleetService.getDriverSettlement(this.driverId).subscribe({
      next: (settlement) => {
        this.settlement.set(settlement);
        this.settlementLoading.set(false);
      },
      error: () => this.settlementLoading.set(false),
    });
  }

  private loadLicenses(): void {
    this.fleetService.getDriverLicenses(this.driverId).subscribe((licenses) => this.licenses.set(licenses));
  }

  expiryStatus(expiryDate: string | null): 'expired' | 'warning' | null {
    if (!expiryDate) return null;
    const days = daysUntil(expiryDate);
    if (days < 0) return 'expired';
    if (days <= EXPIRY_WARNING_DAYS) return 'warning';
    return null;
  }

  addLicense(): void {
    if (this.licenseForm.invalid) {
      this.licenseForm.markAllAsTouched();
      return;
    }

    const value = this.licenseForm.getRawValue();
    this.savingLicense.set(true);

    this.fleetService
      .createDriverLicense(this.driverId, {
        licenseNo: value.licenseNo,
        licenseType: value.licenseType || undefined,
        issuedDate: value.issuedDate || undefined,
        expiryDate: value.expiryDate || undefined,
      })
      .subscribe({
        next: () => {
          this.savingLicense.set(false);
          this.licenseForm.reset({ licenseNo: '', licenseType: '', issuedDate: '', expiryDate: '' });
          this.toast.success('License added');
          this.loadLicenses();
        },
        error: () => this.savingLicense.set(false),
      });
  }

  removeLicense(license: DriverLicenseModel): void {
    this.confirmDialog
      .confirm({
        title: 'Remove license?',
        message: `Remove "${license.licenseType || 'License'}" ${license.licenseNo}?`,
        confirmLabel: 'Remove',
        destructive: true,
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.fleetService.deleteDriverLicense(license.id).subscribe({
          next: () => {
            this.toast.success('License removed');
            this.loadLicenses();
          },
        });
      });
  }
}
