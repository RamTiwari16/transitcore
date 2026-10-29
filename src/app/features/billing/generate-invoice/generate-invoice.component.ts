import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { BillingService } from '../../../services/billing.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { CustomerModel, UninvoicedShipmentModel } from '../../../models/billing.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { PageTitleService } from '../../../core/services/page-title.service';
import { InrPipe } from '../../../shared/pipes/inr.pipe';
import { toLocalIsoDate } from '../../../shared/util/date';

interface FilterFormModel {
  customerId: FormControl<number | null>;
  fromDate: FormControl<string>;
  toDate: FormControl<string>;
}

interface InvoiceFormModel {
  invoiceNo: FormControl<string>;
  invoiceDate: FormControl<string>;
  dueDate: FormControl<string>;
  discountAmount: FormControl<number | null>;
  taxAmount: FormControl<number | null>;
  statusId: FormControl<number | null>;
}

@Component({
  selector: 'app-generate-invoice',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatCheckboxModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatIconModule,
    EmptyStateComponent,
    InrPipe,
    DatePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './generate-invoice.component.html',
  styleUrl: './generate-invoice.component.scss',
})
export class GenerateInvoiceComponent {
  private readonly billingService = inject(BillingService);
  private readonly lookupService = inject(LookupService);
  private readonly toast = inject(ToastService);
  private readonly router = inject(Router);
  private readonly pageTitleService = inject(PageTitleService);

  readonly customers = signal<CustomerModel[]>([]);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly shipments = signal<UninvoicedShipmentModel[] | null>(null);
  readonly loadingShipments = signal(false);
  readonly generating = signal(false);
  readonly selectedIds = signal<Set<number>>(new Set());
  private loadedCustomerId: number | null = null;

  readonly filterForm = new FormGroup<FilterFormModel>({
    customerId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    fromDate: new FormControl(this.monthAgo(), { nonNullable: true, validators: [Validators.required] }),
    toDate: new FormControl(this.today(), { nonNullable: true, validators: [Validators.required] }),
  });

  readonly invoiceForm = new FormGroup<InvoiceFormModel>({
    invoiceNo: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(30)] }),
    invoiceDate: new FormControl(this.today(), { nonNullable: true, validators: [Validators.required] }),
    dueDate: new FormControl(this.today(), { nonNullable: true, validators: [Validators.required] }),
    discountAmount: new FormControl<number | null>(0, { validators: [Validators.min(0)] }),
    taxAmount: new FormControl<number | null>(0, { validators: [Validators.min(0)] }),
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
  });

  readonly selectedShipments = computed(() => {
    const ids = this.selectedIds();
    return (this.shipments() ?? []).filter((s) => ids.has(s.id));
  });

  readonly estimatedTotal = computed(() =>
    this.selectedShipments().reduce((sum, s) => sum + (s.estimatedAmount ?? 0), 0),
  );

  // Shipments without a matching rate card have no price, so invoicing them would create ₹0 lines.
  readonly selectableShipments = computed(() => (this.shipments() ?? []).filter((s) => s.estimatedAmount !== null));

  readonly allSelected = computed(() => {
    const selectable = this.selectableShipments();
    return selectable.length > 0 && selectable.every((s) => this.selectedIds().has(s.id));
  });

  readonly someSelected = computed(() => this.selectedIds().size > 0 && !this.allSelected());

  constructor() {
    this.pageTitleService.setTitle('Generate Invoice from Shipments');
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.billingService.getCustomers(true).subscribe((customers) => this.customers.set(customers));
    this.lookupService.getStatusCodes('Invoice').subscribe((statuses) => this.statusOptions.set(statuses));

    // The loaded list belongs to one customer; switching customer must not leave it billable.
    this.filterForm.controls.customerId.valueChanges.pipe(takeUntilDestroyed()).subscribe(() => {
      this.shipments.set(null);
      this.selectedIds.set(new Set());
      this.loadedCustomerId = null;
    });
  }

  private today(): string {
    return toLocalIsoDate();
  }

  private monthAgo(): string {
    const d = new Date();
    d.setMonth(d.getMonth() - 1);
    return toLocalIsoDate(d);
  }

  loadShipments(): void {
    if (this.filterForm.invalid) {
      this.filterForm.markAllAsTouched();
      return;
    }

    const value = this.filterForm.getRawValue();
    this.loadingShipments.set(true);
    this.selectedIds.set(new Set());

    this.billingService.getUninvoicedShipments(value.customerId!, value.fromDate, value.toDate).subscribe({
      next: (shipments) => {
        this.loadingShipments.set(false);
        if (this.filterForm.controls.customerId.value !== value.customerId) return;
        this.shipments.set(shipments);
        this.loadedCustomerId = value.customerId;
      },
      error: () => this.loadingShipments.set(false),
    });
  }

  isSelected(shipment: UninvoicedShipmentModel): boolean {
    return this.selectedIds().has(shipment.id);
  }

  toggleAll(): void {
    this.selectedIds.set(this.allSelected() ? new Set() : new Set(this.selectableShipments().map((s) => s.id)));
  }

  toggle(shipment: UninvoicedShipmentModel): void {
    if (shipment.estimatedAmount === null) return;
    const next = new Set(this.selectedIds());
    if (next.has(shipment.id)) {
      next.delete(shipment.id);
    } else {
      next.add(shipment.id);
    }
    this.selectedIds.set(next);
  }

  generate(): void {
    this.invoiceForm.markAllAsTouched();

    if (this.invoiceForm.invalid || this.selectedShipments().length === 0) {
      return;
    }

    const customerId = this.loadedCustomerId;
    if (!customerId) return;

    const value = this.invoiceForm.getRawValue();
    this.generating.set(true);

    this.billingService
      .createInvoice({
        invoiceNo: value.invoiceNo,
        customerId,
        invoiceDate: value.invoiceDate,
        dueDate: value.dueDate,
        discountAmount: value.discountAmount ?? 0,
        taxAmount: value.taxAmount ?? 0,
        statusId: value.statusId!,
        lines: this.selectedShipments().map((s) => ({
          shipmentId: s.id,
          description: `Shipment ${s.trackingNo ?? '#' + s.id}: ${s.originCityName} → ${s.destinationCityName}`,
          quantity: 1,
          unitPrice: s.estimatedAmount ?? 0,
        })),
      })
      .subscribe({
        next: (invoiceId) => {
          this.toast.success('Invoice generated successfully');
          this.router.navigate(['/billing/invoices', invoiceId]);
        },
        error: () => this.generating.set(false),
      });
  }
}
