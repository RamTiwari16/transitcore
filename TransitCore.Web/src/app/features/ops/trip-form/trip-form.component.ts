import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { OpsService } from '../../../services/ops.service';
import { FleetService } from '../../../services/fleet.service';
import { LookupService } from '../../../services/lookup.service';
import { VendorService } from '../../../services/vendor.service';
import { ToastService } from '../../../core/services/toast.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { RouteModel, TripConflictModel } from '../../../models/ops.models';
import { VehicleModel, DriverModel } from '../../../models/fleet.models';
import { VendorModel } from '../../../models/vendor.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';

export const OWNERSHIP_TYPES = ['Own', 'Hired'] as const;

interface TripFormModel {
  routeId: FormControl<number | null>;
  ownershipType: FormControl<string>;
  vehicleId: FormControl<number | null>;
  driverId: FormControl<number | null>;
  vendorId: FormControl<number | null>;
  hiredVehicleNo: FormControl<string>;
  hiredDriverName: FormControl<string>;
  hiredDriverPhone: FormControl<string>;
  vendorFreightAmount: FormControl<number | null>;
  scheduledDeparture: FormControl<string>;
  scheduledArrival: FormControl<string>;
  statusId: FormControl<number | null>;
}

// "2026-09-16T00:00:00" (server, no timezone suffix) -> "2026-09-16T00:00"
// (what <input type="datetime-local"> needs) - a plain slice, not a Date
// round-trip, so there's no timezone shift to worry about.
function toDatetimeLocal(iso: string): string {
  return iso.slice(0, 16);
}

@Component({
  selector: 'app-trip-form',
  imports: [RouterLink, ReactiveFormsModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatSelectModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './trip-form.component.html',
  styleUrl: './trip-form.component.scss',
})
export class TripFormComponent implements CanComponentDeactivate {
  readonly ownershipTypes = OWNERSHIP_TYPES;
  readonly routes = signal<RouteModel[]>([]);
  readonly vehicles = signal<VehicleModel[]>([]);
  readonly drivers = signal<DriverModel[]>([]);
  readonly vendors = signal<VendorModel[]>([]);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly saving = signal(false);
  readonly loading = signal(false);
  private submitted = false;

  private readonly tripId = signal<number | null>(null);
  readonly isEditMode = computed(() => this.tripId() !== null);

  readonly form = new FormGroup<TripFormModel>({
    routeId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    ownershipType: new FormControl('Own', { nonNullable: true, validators: [Validators.required] }),
    vehicleId: new FormControl<number | null>(null),
    driverId: new FormControl<number | null>(null),
    vendorId: new FormControl<number | null>(null),
    hiredVehicleNo: new FormControl('', { nonNullable: true }),
    hiredDriverName: new FormControl('', { nonNullable: true }),
    hiredDriverPhone: new FormControl('', { nonNullable: true }),
    vendorFreightAmount: new FormControl<number | null>(null),
    scheduledDeparture: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    scheduledArrival: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
  });

  constructor(
    private opsService: OpsService,
    private fleetService: FleetService,
    private lookupService: LookupService,
    private vendorService: VendorService,
    private toast: ToastService,
    private confirmDialog: ConfirmDialogService,
    private router: Router,
    private route: ActivatedRoute,
  ) {
    const pageTitleService = inject(PageTitleService);
    effect(() => pageTitleService.setTitle(this.isEditMode() ? 'Edit Trip' : 'Schedule Trip'));
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));

    this.opsService.getRoutes().subscribe((r) => this.routes.set(r));
    this.fleetService.getVehicles(1, 100).subscribe((r) => this.vehicles.set(r.items));
    this.fleetService.getDrivers().subscribe((d) => this.drivers.set(d));
    this.vendorService.getVendors(true).subscribe((v) => this.vendors.set(v));
    this.lookupService.getStatusCodes('Trip').subscribe((s) => this.statusOptions.set(s));

    const idParam = this.route.snapshot.paramMap.get('id');
    if (idParam) {
      const id = Number(idParam);
      this.tripId.set(id);
      this.loading.set(true);
      this.opsService.getTripById(id).subscribe({
        next: (trip) => {
          this.form.patchValue({
            routeId: trip.routeId,
            ownershipType: trip.ownershipType,
            vehicleId: trip.vehicleId,
            driverId: trip.driverId,
            vendorId: trip.vendorId,
            hiredVehicleNo: trip.hiredVehicleNo ?? '',
            hiredDriverName: trip.hiredDriverName ?? '',
            hiredDriverPhone: trip.hiredDriverPhone ?? '',
            vendorFreightAmount: trip.vendorFreightAmount,
            scheduledDeparture: toDatetimeLocal(trip.scheduledDeparture),
            scheduledArrival: toDatetimeLocal(trip.scheduledArrival),
            statusId: trip.statusId,
          });
          // Status changes go through the trip detail page's own workflow
          // (audited via status history) - this form's update endpoint
          // deliberately never touches it, so editing it here would silently
          // do nothing. Disabling it is more honest than leaving it live.
          this.form.controls.statusId.disable();
          this.loading.set(false);
        },
        error: () => this.loading.set(false),
      });
    }
  }

  isOwn(): boolean {
    return this.form.controls.ownershipType.value === 'Own';
  }

  hasUnsavedChanges(): boolean {
    return this.form.dirty && !this.submitted;
  }

  // Mirrors the backend's OpsController.ValidateOwnership - a clean,
  // immediate message beats waiting on the API's 400 for the same rule.
  private validateOwnership(): string | null {
    const value = this.form.getRawValue();
    if (value.ownershipType === 'Own') {
      if (value.vehicleId === null || value.driverId === null) return 'An Own trip requires both a vehicle and a driver';
    } else {
      if (value.vendorId === null || !value.hiredVehicleNo) return 'A Hired trip requires a vendor and a hired vehicle number';
    }
    return null;
  }

  save(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const ownershipError = this.validateOwnership();
    if (ownershipError) {
      this.toast.error(ownershipError);
      return;
    }

    const value = this.form.getRawValue();
    const id = this.tripId();

    // Same-driver-or-same-vehicle, overlapping-window check against every
    // other active trip - the actual "dispatch conflict detection" ask, run
    // right before save rather than as a separate board, so it catches a
    // double-booking mistake at the moment it would happen instead of
    // requiring a dispatcher to go find and check a different screen first.
    // A Hired trip has no fleet vehicle/driver, so it simply finds nothing.
    this.opsService
      .checkTripConflicts({
        driverId: value.driverId ?? undefined,
        vehicleId: value.vehicleId ?? undefined,
        scheduledDeparture: `${value.scheduledDeparture}:00`,
        scheduledArrival: `${value.scheduledArrival}:00`,
        excludeTripId: id ?? undefined,
      })
      .subscribe((conflicts) => {
        if (conflicts.length === 0) {
          this.doSave(id);
          return;
        }

        this.confirmDialog
          .confirm({
            title: 'Scheduling conflict detected',
            message: this.describeConflicts(conflicts),
            confirmLabel: 'Save anyway',
            cancelLabel: 'Go back and fix it',
            destructive: true,
          })
          .subscribe((confirmed) => {
            if (confirmed) this.doSave(id);
          });
      });
  }

  private describeConflicts(conflicts: TripConflictModel[]): string {
    const lines = conflicts.map((c) => {
      const who = c.isDriverConflict && c.isVehicleConflict ? 'Driver & vehicle' : c.isDriverConflict ? 'Driver' : 'Vehicle';
      return `${who} already on "${c.routeName}" (${c.registrationNo}, ${c.driverName}), ${this.formatRange(c.scheduledDeparture, c.scheduledArrival)}`;
    });
    return `This assignment overlaps with:\n${lines.join('\n')}`;
  }

  private formatRange(start: string, end: string): string {
    const fmt = (v: string) =>
      new Date(v).toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
    return `${fmt(start)} - ${fmt(end)}`;
  }

  private doSave(id: number | null): void {
    const value = this.form.getRawValue();
    this.saving.set(true);

    // Plain local wall-clock strings (matching the conflict check just run
    // above and toDatetimeLocal() on the read side), not a Date/toISOString()
    // round-trip - that shifts by the browser's timezone offset on the way
    // out with nothing to reverse it on the way back in, so a trip created
    // at "14:00" could round-trip and display as a different hour. Fixing
    // this here too (not just in the new conflict check) since leaving them
    // inconsistent would mean the conflict check compares a different time
    // window than what actually gets saved.
    const scheduledDeparture = `${value.scheduledDeparture}:00`;
    const scheduledArrival = `${value.scheduledArrival}:00`;

    const ownershipFields = {
      ownershipType: value.ownershipType,
      vehicleId: value.ownershipType === 'Own' ? value.vehicleId! : undefined,
      driverId: value.ownershipType === 'Own' ? value.driverId! : undefined,
      vendorId: value.ownershipType === 'Hired' ? value.vendorId! : undefined,
      hiredVehicleNo: value.ownershipType === 'Hired' ? value.hiredVehicleNo : undefined,
      hiredDriverName: value.ownershipType === 'Hired' ? value.hiredDriverName || undefined : undefined,
      hiredDriverPhone: value.ownershipType === 'Hired' ? value.hiredDriverPhone || undefined : undefined,
      vendorFreightAmount: value.ownershipType === 'Hired' ? value.vendorFreightAmount ?? undefined : undefined,
    };

    const save$: Observable<unknown> = id
      ? this.opsService.updateTrip({
          tripId: id,
          routeId: value.routeId!,
          scheduledDeparture,
          scheduledArrival,
          ...ownershipFields,
        })
      : this.opsService.createTrip({
          routeId: value.routeId!,
          scheduledDeparture,
          scheduledArrival,
          statusId: value.statusId!,
          ...ownershipFields,
        });

    save$.subscribe({
      next: () => {
        this.submitted = true;
        this.toast.success(id ? 'Trip updated successfully' : 'Trip scheduled successfully');
        this.router.navigate(['/ops/trips']);
      },
      // errorInterceptor already surfaces the failure as a toast - this
      // only needs to re-enable the form so the user can retry.
      error: () => this.saving.set(false),
    });
  }
}
