import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { FleetService } from '../../../services/fleet.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { VehicleTypeModel } from '../../../models/fleet.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';

interface VehicleFormModel {
  registrationNo: FormControl<string>;
  vehicleTypeId: FormControl<number | null>;
  make: FormControl<string>;
  model: FormControl<string>;
  manufactureYear: FormControl<number | null>;
  capacityKg: FormControl<number | null>;
  statusId: FormControl<number | null>;
}

@Component({
  selector: 'app-vehicle-form',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatIconModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './vehicle-form.component.html',
  styleUrl: './vehicle-form.component.scss',
})
export class VehicleFormComponent implements CanComponentDeactivate {
  readonly vehicleTypes = signal<VehicleTypeModel[]>([]);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly saving = signal(false);
  private submitted = false;

  readonly form = new FormGroup<VehicleFormModel>({
    registrationNo: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(30)] }),
    vehicleTypeId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    make: new FormControl('', { nonNullable: true }),
    model: new FormControl('', { nonNullable: true }),
    manufactureYear: new FormControl<number | null>(null, { validators: [Validators.min(1980), Validators.max(2100)] }),
    capacityKg: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(1)] }),
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
  });

  constructor(
    private fleetService: FleetService,
    private lookupService: LookupService,
    private toast: ToastService,
    private router: Router,
  ) {
    this.fleetService.getVehicleTypes().subscribe((types) => this.vehicleTypes.set(types));
    this.lookupService.getStatusCodes('Vehicle').subscribe((statuses) => this.statusOptions.set(statuses));
  }

  hasUnsavedChanges(): boolean {
    return this.form.dirty && !this.submitted;
  }

  save(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const value = this.form.getRawValue();
    this.saving.set(true);

    this.fleetService
      .createVehicle({
        registrationNo: value.registrationNo,
        vehicleTypeId: value.vehicleTypeId!,
        make: value.make || undefined,
        model: value.model || undefined,
        manufactureYear: value.manufactureYear ?? undefined,
        capacityKg: value.capacityKg!,
        statusId: value.statusId!,
      })
      .subscribe({
        next: () => {
          this.submitted = true;
          this.toast.success('Vehicle created successfully');
          this.router.navigate(['/fleet/vehicles']);
        },
        error: (err) => {
          this.saving.set(false);
          this.toast.error(err?.error?.message || 'Failed to create vehicle');
        },
      });
  }
}
