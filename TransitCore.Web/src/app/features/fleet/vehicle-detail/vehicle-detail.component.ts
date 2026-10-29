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
import {
  FuelLogModel,
  MaintenanceRecordModel,
  VehicleDocumentModel,
  VehicleModel,
} from '../../../models/fleet.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { PageTitleService } from '../../../core/services/page-title.service';

interface DocumentFormModel {
  documentType: FormControl<string>;
  documentNo: FormControl<string>;
  issuedDate: FormControl<string>;
  expiryDate: FormControl<string>;
}

interface MaintenanceFormModel {
  serviceDate: FormControl<string>;
  description: FormControl<string>;
  cost: FormControl<number | null>;
  odometerKm: FormControl<number | null>;
  performedBy: FormControl<string>;
}

interface FuelLogFormModel {
  fuelDate: FormControl<string>;
  liters: FormControl<number | null>;
  cost: FormControl<number | null>;
  odometerKm: FormControl<number | null>;
}

// Documents expiring within this many days are flagged in the UI - matches
// the default the Dashboard alert query uses.
const EXPIRY_WARNING_DAYS = 30;

function daysUntil(dateStr: string): number {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(dateStr);
  return Math.round((target.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
}

@Component({
  selector: 'app-vehicle-detail',
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
  templateUrl: './vehicle-detail.component.html',
  styleUrl: './vehicle-detail.component.scss',
})
export class VehicleDetailComponent {
  private readonly fleetService = inject(FleetService);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly toast = inject(ToastService);
  private readonly route = inject(ActivatedRoute);
  private readonly pageTitleService = inject(PageTitleService);
  private readonly vehicleId = Number(this.route.snapshot.paramMap.get('id'));

  readonly vehicle = signal<VehicleModel | null>(null);
  readonly loading = signal(true);

  readonly documents = signal<VehicleDocumentModel[]>([]);
  readonly maintenanceRecords = signal<MaintenanceRecordModel[]>([]);
  readonly fuelLogs = signal<FuelLogModel[]>([]);
  readonly savingDocument = signal(false);
  readonly savingMaintenance = signal(false);
  readonly savingFuelLog = signal(false);

  readonly documentForm = new FormGroup<DocumentFormModel>({
    documentType: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    documentNo: new FormControl('', { nonNullable: true }),
    issuedDate: new FormControl('', { nonNullable: true }),
    expiryDate: new FormControl('', { nonNullable: true }),
  });

  readonly maintenanceForm = new FormGroup<MaintenanceFormModel>({
    serviceDate: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    description: new FormControl('', { nonNullable: true }),
    cost: new FormControl<number | null>(0, { validators: [Validators.required, Validators.min(0)] }),
    odometerKm: new FormControl<number | null>(null, { validators: [Validators.min(0)] }),
    performedBy: new FormControl('', { nonNullable: true }),
  });

  readonly fuelLogForm = new FormGroup<FuelLogFormModel>({
    fuelDate: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    liters: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0.01)] }),
    cost: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
    odometerKm: new FormControl<number | null>(null, { validators: [Validators.min(0)] }),
  });

  constructor() {
    effect(() => this.pageTitleService.setTitle(this.vehicle()?.registrationNo ?? null));
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.fleetService.getVehicleById(this.vehicleId).subscribe({
      next: (vehicle) => {
        this.vehicle.set(vehicle);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
    this.loadDocuments();
    this.loadMaintenance();
    this.loadFuelLogs();
  }

  private loadDocuments(): void {
    this.fleetService.getVehicleDocuments(this.vehicleId).subscribe((docs) => this.documents.set(docs));
  }

  private loadMaintenance(): void {
    this.fleetService.getMaintenanceRecords(this.vehicleId).subscribe((records) => this.maintenanceRecords.set(records));
  }

  private loadFuelLogs(): void {
    this.fleetService.getFuelLogs(this.vehicleId).subscribe((logs) => this.fuelLogs.set(logs));
  }

  // Flags a document row: 'expired' | 'warning' (within 30 days) | null.
  expiryStatus(expiryDate: string | null): 'expired' | 'warning' | null {
    if (!expiryDate) return null;
    const days = daysUntil(expiryDate);
    if (days < 0) return 'expired';
    if (days <= EXPIRY_WARNING_DAYS) return 'warning';
    return null;
  }

  addDocument(): void {
    if (this.documentForm.invalid) {
      this.documentForm.markAllAsTouched();
      return;
    }

    const value = this.documentForm.getRawValue();
    this.savingDocument.set(true);

    this.fleetService
      .createVehicleDocument(this.vehicleId, {
        documentType: value.documentType,
        documentNo: value.documentNo || undefined,
        issuedDate: value.issuedDate || undefined,
        expiryDate: value.expiryDate || undefined,
      })
      .subscribe({
        next: () => {
          this.savingDocument.set(false);
          this.documentForm.reset({ documentType: '', documentNo: '', issuedDate: '', expiryDate: '' });
          this.toast.success('Document added');
          this.loadDocuments();
        },
        error: () => this.savingDocument.set(false),
      });
  }

  removeDocument(document: VehicleDocumentModel): void {
    this.confirmDialog
      .confirm({
        title: 'Remove document?',
        message: `Remove "${document.documentType}"${document.documentNo ? ' (' + document.documentNo + ')' : ''}?`,
        confirmLabel: 'Remove',
        destructive: true,
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.fleetService.deleteVehicleDocument(document.id).subscribe({
          next: () => {
            this.toast.success('Document removed');
            this.loadDocuments();
          },
        });
      });
  }

  addMaintenance(): void {
    if (this.maintenanceForm.invalid) {
      this.maintenanceForm.markAllAsTouched();
      return;
    }

    const value = this.maintenanceForm.getRawValue();
    this.savingMaintenance.set(true);

    this.fleetService
      .createMaintenanceRecord(this.vehicleId, {
        serviceDate: value.serviceDate,
        description: value.description || undefined,
        cost: value.cost!,
        odometerKm: value.odometerKm ?? undefined,
        performedBy: value.performedBy || undefined,
      })
      .subscribe({
        next: () => {
          this.savingMaintenance.set(false);
          this.maintenanceForm.reset({ serviceDate: '', description: '', cost: 0, odometerKm: null, performedBy: '' });
          this.toast.success('Maintenance record added');
          this.loadMaintenance();
        },
        error: () => this.savingMaintenance.set(false),
      });
  }

  removeMaintenance(record: MaintenanceRecordModel): void {
    this.confirmDialog
      .confirm({
        title: 'Remove maintenance record?',
        message: `Remove the service record from ${record.serviceDate}?`,
        confirmLabel: 'Remove',
        destructive: true,
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.fleetService.deleteMaintenanceRecord(record.id).subscribe({
          next: () => {
            this.toast.success('Maintenance record removed');
            this.loadMaintenance();
          },
        });
      });
  }

  addFuelLog(): void {
    if (this.fuelLogForm.invalid) {
      this.fuelLogForm.markAllAsTouched();
      return;
    }

    const value = this.fuelLogForm.getRawValue();
    this.savingFuelLog.set(true);

    this.fleetService
      .createFuelLog(this.vehicleId, {
        fuelDate: value.fuelDate,
        liters: value.liters!,
        cost: value.cost!,
        odometerKm: value.odometerKm ?? undefined,
      })
      .subscribe({
        next: () => {
          this.savingFuelLog.set(false);
          this.fuelLogForm.reset({ fuelDate: '', liters: null, cost: null, odometerKm: null });
          this.toast.success('Fuel log added');
          this.loadFuelLogs();
        },
        error: () => this.savingFuelLog.set(false),
      });
  }

  removeFuelLog(log: FuelLogModel): void {
    this.confirmDialog
      .confirm({
        title: 'Remove fuel log?',
        message: `Remove the fuel log from ${log.fuelDate}?`,
        confirmLabel: 'Remove',
        destructive: true,
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.fleetService.deleteFuelLog(log.id).subscribe({
          next: () => {
            this.toast.success('Fuel log removed');
            this.loadFuelLogs();
          },
        });
      });
  }
}
