import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { FleetService } from '../../../services/fleet.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { StatusCodeModel } from '../../../models/lookup.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';

interface DriverFormModel {
  fullName: FormControl<string>;
  phoneNo: FormControl<string>;
  email: FormControl<string>;
  dateOfBirth: FormControl<string>;
  hireDate: FormControl<string>;
  statusId: FormControl<number | null>;
}

@Component({
  selector: 'app-driver-form',
  imports: [RouterLink, ReactiveFormsModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatSelectModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './driver-form.component.html',
  styleUrl: './driver-form.component.scss',
})
export class DriverFormComponent implements CanComponentDeactivate {
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly saving = signal(false);
  readonly loading = signal(false);
  private submitted = false;

  private readonly driverId = signal<number | null>(null);
  readonly isEditMode = computed(() => this.driverId() !== null);

  readonly form = new FormGroup<DriverFormModel>({
    fullName: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(200)] }),
    phoneNo: new FormControl('', { nonNullable: true }),
    email: new FormControl('', { nonNullable: true, validators: [Validators.email] }),
    dateOfBirth: new FormControl('', { nonNullable: true }),
    hireDate: new FormControl('', { nonNullable: true }),
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
    effect(() => pageTitleService.setTitle(this.isEditMode() ? 'Edit Driver' : 'Add Driver'));
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));

    this.lookupService.getStatusCodes('Driver').subscribe((statuses) => this.statusOptions.set(statuses));

    const idParam = this.route.snapshot.paramMap.get('id');
    if (idParam) {
      const id = Number(idParam);
      this.driverId.set(id);
      this.loading.set(true);
      this.fleetService.getDriverById(id).subscribe({
        next: (driver) => {
          this.form.patchValue({
            fullName: driver.fullName,
            phoneNo: driver.phoneNo ?? '',
            email: driver.email ?? '',
            dateOfBirth: driver.dateOfBirth ?? '',
            hireDate: driver.hireDate ?? '',
            statusId: driver.statusId,
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
      fullName: value.fullName,
      phoneNo: value.phoneNo || undefined,
      email: value.email || undefined,
      dateOfBirth: value.dateOfBirth || undefined,
      hireDate: value.hireDate || undefined,
      statusId: value.statusId!,
    };

    this.saving.set(true);

    const id = this.driverId();
    const save$: Observable<unknown> = id
      ? this.fleetService.updateDriver({ ...request, driverId: id })
      : this.fleetService.createDriver(request);

    save$.subscribe({
      next: () => {
        this.submitted = true;
        this.toast.success(id ? 'Driver updated successfully' : 'Driver added successfully');
        this.router.navigate(['/fleet/drivers']);
      },
      // errorInterceptor already surfaces the failure as a toast - this
      // only needs to re-enable the form so the user can retry.
      error: () => this.saving.set(false),
    });
  }
}
