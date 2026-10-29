import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { FleetService } from '../../../services/fleet.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
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
  readonly loading = signal(false);
  private submitted = false;

  // Present on /fleet/vehicles/:id/edit, absent on /fleet/vehicles/new - the
  // one flag this whole component branches on to be both screens at once.
  private readonly vehicleId = signal<number | null>(null);
  readonly isEditMode = computed(() => this.vehicleId() !== null);

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
    private route: ActivatedRoute,
  ) {
    const pageTitleService = inject(PageTitleService);
    effect(() => pageTitleService.setTitle(this.isEditMode() ? 'Edit Vehicle' : 'Add Vehicle'));
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));

    this.fleetService.getVehicleTypes().subscribe((types) => this.vehicleTypes.set(types));
    this.lookupService.getStatusCodes('Vehicle').subscribe((statuses) => this.statusOptions.set(statuses));

    const idParam = this.route.snapshot.paramMap.get('id');
    if (idParam) {
      const id = Number(idParam);
      this.vehicleId.set(id);
      this.loading.set(true);
      this.fleetService.getVehicleById(id).subscribe({
        next: (vehicle) => {
          this.form.patchValue({
            registrationNo: vehicle.registrationNo,
            vehicleTypeId: vehicle.vehicleTypeId,
            make: vehicle.make ?? '',
            model: vehicle.model ?? '',
            manufactureYear: vehicle.manufactureYear,
            capacityKg: vehicle.capacityKg,
            statusId: vehicle.statusId,
          });
          this.loading.set(false);
        },
        error: () => this.loading.set(false),
      });
    }
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
    const request = {
      registrationNo: value.registrationNo,
      vehicleTypeId: value.vehicleTypeId!,
      make: value.make || undefined,
      model: value.model || undefined,
      manufactureYear: value.manufactureYear ?? undefined,
      capacityKg: value.capacityKg!,
      statusId: value.statusId!,
    };

    this.saving.set(true);

    const id = this.vehicleId();
    const save$: Observable<unknown> = id
      ? this.fleetService.updateVehicle({ ...request, vehicleId: id })
      : this.fleetService.createVehicle(request);

    save$.subscribe({
      next: () => {
        this.submitted = true;
        this.toast.success(id ? 'Vehicle updated successfully' : 'Vehicle created successfully');
        this.router.navigate(['/fleet/vehicles']);
      },
      // errorInterceptor already surfaces the failure as a toast - this
      // only needs to re-enable the form so the user can retry.
      error: () => this.saving.set(false),
    });
  }
}
