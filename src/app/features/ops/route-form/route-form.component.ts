import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { OpsService } from '../../../services/ops.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { CityModel } from '../../../models/lookup.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';

interface RouteFormModel {
  name: FormControl<string>;
  originCityId: FormControl<number | null>;
  destinationCityId: FormControl<number | null>;
  distanceKm: FormControl<number | null>;
}

@Component({
  selector: 'app-route-form',
  imports: [RouterLink, ReactiveFormsModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatSelectModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './route-form.component.html',
  styleUrl: './route-form.component.scss',
})
export class RouteFormComponent implements CanComponentDeactivate {
  readonly cities = signal<CityModel[]>([]);
  readonly saving = signal(false);
  private submitted = false;

  readonly form = new FormGroup<RouteFormModel>({
    name: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(200)] }),
    originCityId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    destinationCityId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    distanceKm: new FormControl<number | null>(null, { validators: [Validators.min(0)] }),
  });

  constructor(
    private opsService: OpsService,
    private lookupService: LookupService,
    private toast: ToastService,
    private router: Router,
  ) {
    this.lookupService.getCities().subscribe({
      next: (cities) => this.cities.set(cities),
      error: () => this.toast.error('Failed to load cities'),
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
      .createRoute({
        name: value.name,
        originCityId: value.originCityId!,
        destinationCityId: value.destinationCityId!,
        distanceKm: value.distanceKm ?? undefined,
      })
      .subscribe({
        next: () => {
          this.submitted = true;
          this.toast.success('Route added successfully');
          this.router.navigate(['/ops/routes']);
        },
        error: (err) => {
          this.saving.set(false);
          this.toast.error(err?.error?.message || 'Failed to add route');
        },
      });
  }
}
