import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { OpsService } from '../../../services/ops.service';
import { FleetService } from '../../../services/fleet.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { RouteModel } from '../../../models/ops.models';
import { VehicleModel, DriverModel } from '../../../models/fleet.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';

interface TripFormModel {
  routeId: FormControl<number | null>;
  vehicleId: FormControl<number | null>;
  driverId: FormControl<number | null>;
  scheduledDeparture: FormControl<string>;
  scheduledArrival: FormControl<string>;
  statusId: FormControl<number | null>;
}

@Component({
  selector: 'app-trip-form',
  imports: [RouterLink, ReactiveFormsModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatSelectModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './trip-form.component.html',
  styleUrl: './trip-form.component.scss',
})
export class TripFormComponent implements CanComponentDeactivate {
  readonly routes = signal<RouteModel[]>([]);
  readonly vehicles = signal<VehicleModel[]>([]);
  readonly drivers = signal<DriverModel[]>([]);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly saving = signal(false);
  private submitted = false;

  readonly form = new FormGroup<TripFormModel>({
    routeId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    vehicleId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    driverId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    scheduledDeparture: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    scheduledArrival: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
  });

  constructor(
    private opsService: OpsService,
    private fleetService: FleetService,
    private lookupService: LookupService,
    private toast: ToastService,
    private router: Router,
  ) {
    this.opsService.getRoutes().subscribe({
      next: (r) => this.routes.set(r),
      error: () => this.toast.error('Failed to load routes'),
    });
    this.fleetService.getVehicles(1, 100).subscribe({
      next: (r) => this.vehicles.set(r.items),
      error: () => this.toast.error('Failed to load vehicles'),
    });
    this.fleetService.getDrivers().subscribe({
      next: (d) => this.drivers.set(d),
      error: () => this.toast.error('Failed to load drivers'),
    });
    this.lookupService.getStatusCodes('Trip').subscribe({
      next: (s) => this.statusOptions.set(s),
      error: () => this.toast.error('Failed to load status options'),
    });
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

    this.opsService
      .createTrip({
        routeId: value.routeId!,
        vehicleId: value.vehicleId!,
        driverId: value.driverId!,
        scheduledDeparture: new Date(value.scheduledDeparture).toISOString(),
        scheduledArrival: new Date(value.scheduledArrival).toISOString(),
        statusId: value.statusId!,
      })
      .subscribe({
        next: () => {
          this.submitted = true;
          this.toast.success('Trip scheduled successfully');
          this.router.navigate(['/ops/trips']);
        },
        error: (err) => {
          this.saving.set(false);
          this.toast.error(err?.error?.message || 'Failed to schedule trip');
        },
      });
  }
}
