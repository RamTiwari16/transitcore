import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { FleetService } from '../../../services/fleet.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
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
  private submitted = false;

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
  ) {
    this.lookupService.getStatusCodes('Driver').subscribe({
      next: (statuses) => this.statusOptions.set(statuses),
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

    this.fleetService
      .createDriver({
        fullName: value.fullName,
        phoneNo: value.phoneNo || undefined,
        email: value.email || undefined,
        dateOfBirth: value.dateOfBirth || undefined,
        hireDate: value.hireDate || undefined,
        statusId: value.statusId!,
      })
      .subscribe({
        next: () => {
          this.submitted = true;
          this.toast.success('Driver added successfully');
          this.router.navigate(['/fleet/drivers']);
        },
        error: (err) => {
          this.saving.set(false);
          this.toast.error(err?.error?.message || 'Failed to add driver');
        },
      });
  }
}
