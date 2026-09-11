import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { FormArray, FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { OpsService } from '../../../services/ops.service';
import { BillingService } from '../../../services/billing.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { CustomerModel } from '../../../models/billing.models';
import { CityModel, StatusCodeModel, UnitOfMeasureModel } from '../../../models/lookup.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';

interface ShipmentItemFormModel {
  description: FormControl<string>;
  quantity: FormControl<number | null>;
  unitOfMeasureId: FormControl<number | null>;
  weightKg: FormControl<number | null>;
}

interface ShipmentFormModel {
  customerId: FormControl<number | null>;
  originCityId: FormControl<number | null>;
  destinationCityId: FormControl<number | null>;
  statusId: FormControl<number | null>;
  shipmentDate: FormControl<string>;
}

@Component({
  selector: 'app-shipment-form',
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
  templateUrl: './shipment-form.component.html',
  styleUrl: './shipment-form.component.scss',
})
export class ShipmentFormComponent implements CanComponentDeactivate {
  readonly customers = signal<CustomerModel[]>([]);
  readonly cities = signal<CityModel[]>([]);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly unitsOfMeasure = signal<UnitOfMeasureModel[]>([]);
  readonly saving = signal(false);
  private submitted = false;

  readonly form = new FormGroup<ShipmentFormModel>({
    customerId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    originCityId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    destinationCityId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    shipmentDate: new FormControl(this.today(), { nonNullable: true, validators: [Validators.required] }),
  });

  readonly items = new FormArray<FormGroup<ShipmentItemFormModel>>([]);

  constructor(
    private opsService: OpsService,
    private billingService: BillingService,
    private lookupService: LookupService,
    private toast: ToastService,
    private router: Router,
  ) {
    this.billingService.getCustomers(true).subscribe({
      next: (c) => this.customers.set(c),
      error: () => this.toast.error('Failed to load customers'),
    });
    this.lookupService.getCities().subscribe({
      next: (c) => this.cities.set(c),
      error: () => this.toast.error('Failed to load cities'),
    });
    this.lookupService.getStatusCodes('Shipment').subscribe({
      next: (s) => this.statusOptions.set(s),
      error: () => this.toast.error('Failed to load status options'),
    });
    this.lookupService.getUnitsOfMeasure().subscribe({
      next: (u) => this.unitsOfMeasure.set(u),
      error: () => this.toast.error('Failed to load units of measure'),
    });

    this.addItem();
  }

  private today(): string {
    return new Date().toISOString().split('T')[0];
  }

  addItem(): void {
    this.items.push(
      new FormGroup<ShipmentItemFormModel>({
        description: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
        quantity: new FormControl<number | null>(1, { validators: [Validators.required, Validators.min(0.01)] }),
        unitOfMeasureId: new FormControl<number | null>(null, { validators: [Validators.required] }),
        weightKg: new FormControl<number | null>(null),
      }),
    );
  }

  removeItem(index: number): void {
    if (this.items.length > 1) {
      this.items.removeAt(index);
    }
  }

  hasUnsavedChanges(): boolean {
    return (this.form.dirty || this.items.dirty) && !this.submitted;
  }

  save(): void {
    this.form.markAllAsTouched();
    this.items.markAllAsTouched();

    if (this.form.invalid || this.items.invalid) {
      return;
    }

    const value = this.form.getRawValue();
    this.saving.set(true);

    this.opsService
      .createShipment({
        customerId: value.customerId!,
        originCityId: value.originCityId!,
        destinationCityId: value.destinationCityId!,
        statusId: value.statusId!,
        shipmentDate: value.shipmentDate,
        items: this.items.controls.map((group) => {
          const item = group.getRawValue();
          return {
            description: item.description,
            quantity: item.quantity!,
            unitOfMeasureId: item.unitOfMeasureId!,
            weightKg: item.weightKg ?? undefined,
          };
        }),
      })
      .subscribe({
        next: () => {
          this.submitted = true;
          this.toast.success('Shipment created successfully');
          this.router.navigate(['/ops/shipments']);
        },
        error: (err) => {
          this.saving.set(false);
          this.toast.error(err?.error?.message || 'Failed to create shipment');
        },
      });
  }
}
