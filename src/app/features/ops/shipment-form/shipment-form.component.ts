import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
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
import { PageTitleService } from '../../../core/services/page-title.service';
import { CustomerModel } from '../../../models/billing.models';
import { CityModel, StatusCodeModel, UnitOfMeasureModel } from '../../../models/lookup.models';
import { ShipmentItemModel, ShipmentParties } from '../../../models/ops.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';
import { toLocalIsoDate } from '../../../shared/util/date';

interface ShipmentItemFormModel {
  description: FormControl<string>;
  quantity: FormControl<number | null>;
  unitOfMeasureId: FormControl<number | null>;
  weightKg: FormControl<number | null>;
  volumeCbm: FormControl<number | null>;
}

interface ShipmentFormModel {
  customerId: FormControl<number | null>;
  originCityId: FormControl<number | null>;
  destinationCityId: FormControl<number | null>;
  statusId: FormControl<number | null>;
  shipmentDate: FormControl<string>;
  freightPaymentTypeId: FormControl<number | null>;
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
  readonly freightPaymentTypes = signal<StatusCodeModel[]>([]);
  readonly unitsOfMeasure = signal<UnitOfMeasureModel[]>([]);
  readonly saving = signal(false);
  readonly loading = signal(false);
  private submitted = false;

  private readonly shipmentId = signal<number | null>(null);
  readonly isEditMode = computed(() => this.shipmentId() !== null);
  // Line items aren't editable through this form yet (see
  // UpdateShipmentRequest's comment) - shown read-only in edit mode instead
  // of silently dropping them or pretending they can be changed here.
  readonly existingItems = signal<ShipmentItemModel[]>([]);
  // Consignor/consignee have no fields on this form yet, but the update
  // endpoint overwrites them, so an edit sends back what was loaded.
  private loadedParties: ShipmentParties | null = null;

  readonly form = new FormGroup<ShipmentFormModel>({
    customerId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    originCityId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    destinationCityId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    shipmentDate: new FormControl(this.today(), { nonNullable: true, validators: [Validators.required] }),
    freightPaymentTypeId: new FormControl<number | null>(null, { validators: [Validators.required] }),
  });

  readonly items = new FormArray<FormGroup<ShipmentItemFormModel>>([]);

  constructor(
    private opsService: OpsService,
    private billingService: BillingService,
    private lookupService: LookupService,
    private toast: ToastService,
    private router: Router,
    private route: ActivatedRoute,
  ) {
    const pageTitleService = inject(PageTitleService);
    effect(() => pageTitleService.setTitle(this.isEditMode() ? 'Edit Shipment' : 'Add Shipment'));
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));

    this.billingService.getCustomers(true).subscribe((c) => this.customers.set(c));
    this.lookupService.getCities().subscribe((c) => this.cities.set(c));
    this.lookupService.getStatusCodes('Shipment').subscribe((s) => this.statusOptions.set(s));
    this.lookupService.getUnitsOfMeasure().subscribe((u) => this.unitsOfMeasure.set(u));

    const idParam = this.route.snapshot.paramMap.get('id');

    // New shipments default to To Be Billed - the only type Generate Invoice picks up.
    this.lookupService.getStatusCodes('FreightPaymentType').subscribe((types) => {
      this.freightPaymentTypes.set(types);
      const freightControl = this.form.controls.freightPaymentTypeId;
      if (!idParam && freightControl.value === null) {
        freightControl.setValue(types.find((t) => t.code === 'TOBEBILLED')?.id ?? null);
      }
    });

    if (idParam) {
      const id = Number(idParam);
      this.shipmentId.set(id);
      this.loading.set(true);
      this.opsService.getShipmentById(id).subscribe({
        next: (shipment) => {
          this.form.patchValue({
            customerId: shipment.customerId,
            originCityId: shipment.originCityId,
            destinationCityId: shipment.destinationCityId,
            statusId: shipment.statusId,
            shipmentDate: shipment.shipmentDate,
            freightPaymentTypeId: shipment.freightPaymentTypeId,
          });
          this.loadedParties = {
            consignorCustomerId: shipment.consignorCustomerId,
            consignorName: shipment.consignorName,
            consignorAddress: shipment.consignorAddress,
            consignorPhone: shipment.consignorPhone,
            consigneeCustomerId: shipment.consigneeCustomerId,
            consigneeName: shipment.consigneeName,
            consigneeAddress: shipment.consigneeAddress,
            consigneePhone: shipment.consigneePhone,
          };
          this.existingItems.set(shipment.items);
          this.loading.set(false);
        },
        error: () => this.loading.set(false),
      });
    } else {
      this.addItem();
    }
  }

  private today(): string {
    return toLocalIsoDate();
  }

  addItem(): void {
    this.items.push(
      new FormGroup<ShipmentItemFormModel>({
        description: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
        quantity: new FormControl<number | null>(1, { validators: [Validators.required, Validators.min(0.01)] }),
        unitOfMeasureId: new FormControl<number | null>(null, { validators: [Validators.required] }),
        weightKg: new FormControl<number | null>(null),
        volumeCbm: new FormControl<number | null>(null),
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

    const id = this.shipmentId();
    if (!id) {
      this.items.markAllAsTouched();
    }

    if (this.form.invalid || (!id && this.items.invalid) || (id && !this.loadedParties)) {
      return;
    }

    const value = this.form.getRawValue();
    this.saving.set(true);

    const save$: Observable<unknown> = id
      ? this.opsService.updateShipment({
          shipmentId: id,
          customerId: value.customerId!,
          originCityId: value.originCityId!,
          destinationCityId: value.destinationCityId!,
          statusId: value.statusId!,
          shipmentDate: value.shipmentDate,
          freightPaymentTypeId: value.freightPaymentTypeId!,
          ...this.loadedParties!,
        })
      : this.opsService.createShipment({
          customerId: value.customerId!,
          originCityId: value.originCityId!,
          destinationCityId: value.destinationCityId!,
          statusId: value.statusId!,
          shipmentDate: value.shipmentDate,
          freightPaymentTypeId: value.freightPaymentTypeId!,
          items: this.items.controls.map((group) => {
            const item = group.getRawValue();
            return {
              description: item.description,
              quantity: item.quantity!,
              unitOfMeasureId: item.unitOfMeasureId!,
              weightKg: item.weightKg ?? undefined,
              volumeCbm: item.volumeCbm ?? undefined,
            };
          }),
        });

    save$.subscribe({
      next: () => {
        this.submitted = true;
        this.toast.success(id ? 'Shipment updated successfully' : 'Shipment created successfully');
        this.router.navigate(['/ops/shipments']);
      },
      // errorInterceptor already surfaces the failure as a toast - this
      // only needs to re-enable the form so the user can retry.
      error: () => this.saving.set(false),
    });
  }
}
