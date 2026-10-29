import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { OpsService } from '../../../services/ops.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { CityModel } from '../../../models/lookup.models';
import { RouteStopModel } from '../../../models/ops.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';

interface RouteFormModel {
  name: FormControl<string>;
  originCityId: FormControl<number | null>;
  destinationCityId: FormControl<number | null>;
  distanceKm: FormControl<number | null>;
}

interface StopFormModel {
  cityId: FormControl<number | null>;
  plannedArrival: FormControl<string>;
}

@Component({
  selector: 'app-route-form',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatIconModule,
    MatTooltipModule,
    EmptyStateComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './route-form.component.html',
  styleUrl: './route-form.component.scss',
})
export class RouteFormComponent implements CanComponentDeactivate {
  readonly cities = signal<CityModel[]>([]);
  readonly saving = signal(false);
  readonly loading = signal(false);
  private submitted = false;

  private readonly routeId = signal<number | null>(null);
  readonly isEditMode = computed(() => this.routeId() !== null);

  readonly stops = signal<RouteStopModel[]>([]);
  readonly savingStop = signal(false);

  readonly form = new FormGroup<RouteFormModel>({
    name: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(200)] }),
    originCityId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    destinationCityId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    distanceKm: new FormControl<number | null>(null, { validators: [Validators.min(0)] }),
  });

  readonly stopForm = new FormGroup<StopFormModel>({
    cityId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    plannedArrival: new FormControl('', { nonNullable: true }),
  });

  constructor(
    private opsService: OpsService,
    private lookupService: LookupService,
    private toast: ToastService,
    private confirmDialog: ConfirmDialogService,
    private router: Router,
    private route: ActivatedRoute,
  ) {
    const pageTitleService = inject(PageTitleService);
    effect(() => pageTitleService.setTitle(this.isEditMode() ? 'Edit Route' : 'Add Route'));
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));

    this.lookupService.getCities().subscribe((cities) => this.cities.set(cities));

    const idParam = this.route.snapshot.paramMap.get('id');
    if (idParam) {
      const id = Number(idParam);
      this.routeId.set(id);
      this.loading.set(true);
      this.opsService.getRouteById(id).subscribe({
        next: (route) => {
          this.form.patchValue({
            name: route.name,
            originCityId: route.originCityId,
            destinationCityId: route.destinationCityId,
            distanceKm: route.distanceKm,
          });
          this.loading.set(false);
        },
        error: () => this.loading.set(false),
      });
      this.loadStops(id);
    }
  }

  private loadStops(routeId: number): void {
    this.opsService.getRouteStops(routeId).subscribe((stops) => this.stops.set(stops));
  }

  addStop(): void {
    const id = this.routeId();
    if (!id || this.stopForm.invalid) {
      this.stopForm.markAllAsTouched();
      return;
    }

    const value = this.stopForm.getRawValue();
    const nextOrder = Math.max(0, ...this.stops().map((s) => s.stopOrder)) + 1;
    this.savingStop.set(true);

    this.opsService
      .createRouteStop(id, {
        cityId: value.cityId!,
        stopOrder: nextOrder,
        plannedArrival: value.plannedArrival ? `${value.plannedArrival}:00` : undefined,
      })
      .subscribe({
        next: () => {
          this.savingStop.set(false);
          this.stopForm.reset({ cityId: null, plannedArrival: '' });
          this.toast.success('Stop added');
          this.loadStops(id);
        },
        error: () => this.savingStop.set(false),
      });
  }

  removeStop(stop: RouteStopModel): void {
    const id = this.routeId();
    if (!id) return;

    this.confirmDialog
      .confirm({ title: 'Remove stop?', message: `Remove the stop at ${stop.cityName}?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.opsService.deleteRouteStop(stop.id).subscribe({
          next: () => {
            this.toast.success('Stop removed');
            this.loadStops(id);
          },
        });
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
    const request = {
      name: value.name,
      originCityId: value.originCityId!,
      destinationCityId: value.destinationCityId!,
      distanceKm: value.distanceKm ?? undefined,
    };

    this.saving.set(true);

    const id = this.routeId();
    const save$: Observable<unknown> = id
      ? this.opsService.updateRoute({ ...request, routeId: id })
      : this.opsService.createRoute(request);

    save$.subscribe({
      next: () => {
        this.submitted = true;
        this.toast.success(id ? 'Route updated successfully' : 'Route added successfully');
        this.router.navigate(['/ops/routes']);
      },
      // errorInterceptor already surfaces the failure as a toast - this
      // only needs to re-enable the form so the user can retry.
      error: () => this.saving.set(false),
    });
  }
}
