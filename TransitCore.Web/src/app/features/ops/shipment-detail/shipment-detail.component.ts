import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatTabsModule } from '@angular/material/tabs';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatTooltipModule } from '@angular/material/tooltip';
import { OpsService } from '../../../services/ops.service';
import { BillingService } from '../../../services/billing.service';
import { LookupService } from '../../../services/lookup.service';
import { ClaimService } from '../../../services/claim.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { environment } from '../../../../environments/environment';
import { ConsignmentNoteDetailModel, ShipmentItemDeliveryLineModel } from '../../../models/ops.models';
import { ShipmentChargeModel } from '../../../models/billing.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { ClaimModel } from '../../../models/claim.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { InrPipe } from '../../../shared/pipes/inr.pipe';
import { toLocalIsoDate } from '../../../shared/util/date';

interface DeliveryFormModel {
  deliveredQty: FormControl<number | null>;
  shortQty: FormControl<number | null>;
  damagedQty: FormControl<number | null>;
  remarks: FormControl<string>;
}

interface ClaimFormModel {
  claimantName: FormControl<string>;
  claimantPhone: FormControl<string>;
  amountClaimed: FormControl<number | null>;
  notes: FormControl<string>;
}

interface ChargeFormModel {
  chargeType: FormControl<string>;
  amount: FormControl<number | null>;
  description: FormControl<string>;
  isOverridden: FormControl<boolean>;
  overrideReason: FormControl<string>;
}

interface CancelFormModel {
  cancelReason: FormControl<string>;
}

interface EwayBillFormModel {
  ewayBillNo: FormControl<string>;
  ewayBillGeneratedDate: FormControl<string>;
  ewayBillValidUntil: FormControl<string>;
}

interface GenerateInvoiceFormModel {
  invoiceNo: FormControl<string>;
  invoiceDate: FormControl<string>;
  dueDate: FormControl<string>;
  discountAmount: FormControl<number | null>;
  taxAmount: FormControl<number | null>;
  statusId: FormControl<number | null>;
}

@Component({
  selector: 'app-shipment-detail',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatTabsModule,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatCheckboxModule,
    MatTooltipModule,
    EmptyStateComponent,
    InrPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './shipment-detail.component.html',
  styleUrl: './shipment-detail.component.scss',
})
export class ShipmentDetailComponent {
  readonly fileBaseUrl = environment.apiUrl;

  readonly cn = signal<ConsignmentNoteDetailModel | null>(null);
  readonly loading = signal(true);
  readonly downloadingPdf = signal(false);

  readonly deliveryLines = signal<ShipmentItemDeliveryLineModel[]>([]);
  readonly savingDeliveryIds = signal<Set<number>>(new Set());
  readonly editingDeliveryIds = signal<Set<number>>(new Set());
  private readonly deliveryForms = new Map<number, FormGroup<DeliveryFormModel>>();
  private readonly selectedPhotosByItem = new Map<number, File[]>();

  readonly claims = signal<ClaimModel[]>([]);
  readonly claimStatusOptions = signal<StatusCodeModel[]>([]);
  readonly savingClaim = signal(false);

  readonly charges = signal<ShipmentChargeModel[]>([]);
  readonly savingCharge = signal(false);
  readonly selectedChargeIds = signal<Set<number>>(new Set());
  readonly invoiceStatusOptions = signal<StatusCodeModel[]>([]);
  readonly generating = signal(false);
  readonly cancelling = signal(false);
  readonly savingEwayBill = signal(false);

  private readonly route = inject(ActivatedRoute);
  private readonly pageTitleService = inject(PageTitleService);
  private readonly opsService = inject(OpsService);
  private readonly billingService = inject(BillingService);
  private readonly lookupService = inject(LookupService);
  private readonly claimService = inject(ClaimService);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly toast = inject(ToastService);
  private readonly router = inject(Router);
  private readonly shipmentId = Number(this.route.snapshot.paramMap.get('id'));

  readonly chargeableCharges = computed(() => this.charges().filter((c) => !c.isInvoiced));
  readonly selectedCharges = computed(() => {
    const ids = this.selectedChargeIds();
    return this.charges().filter((c) => ids.has(c.id));
  });
  readonly selectedTotal = computed(() => this.selectedCharges().reduce((sum, c) => sum + c.amount, 0));

  readonly chargeForm = new FormGroup<ChargeFormModel>({
    chargeType: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    amount: new FormControl<number | null>(null, { validators: [Validators.required] }),
    description: new FormControl('', { nonNullable: true }),
    isOverridden: new FormControl(false, { nonNullable: true }),
    overrideReason: new FormControl('', { nonNullable: true }),
  });

  readonly cancelForm = new FormGroup<CancelFormModel>({
    cancelReason: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });

  readonly ewayBillForm = new FormGroup<EwayBillFormModel>({
    ewayBillNo: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    ewayBillGeneratedDate: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    ewayBillValidUntil: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });

  readonly generateInvoiceForm = new FormGroup<GenerateInvoiceFormModel>({
    invoiceNo: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(30)] }),
    invoiceDate: new FormControl(toLocalIsoDate(), { nonNullable: true, validators: [Validators.required] }),
    dueDate: new FormControl(toLocalIsoDate(), { nonNullable: true, validators: [Validators.required] }),
    discountAmount: new FormControl<number | null>(0, { validators: [Validators.min(0)] }),
    taxAmount: new FormControl<number | null>(0, { validators: [Validators.min(0)] }),
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
  });

  readonly claimForm = new FormGroup<ClaimFormModel>({
    claimantName: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    claimantPhone: new FormControl('', { nonNullable: true }),
    amountClaimed: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
    notes: new FormControl('', { nonNullable: true }),
  });

  constructor() {
    this.pageTitleService.setTitle('Shipment');
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.lookupService.getStatusCodes('Invoice').subscribe((s) => this.invoiceStatusOptions.set(s));
    this.lookupService.getStatusCodes('Claim').subscribe((s) => this.claimStatusOptions.set(s));
    this.load();
    this.loadCharges();
    this.loadDeliveryLines();
    this.loadClaims();
  }

  private load(): void {
    this.loading.set(true);
    this.opsService.getConsignmentNoteByShipmentId(this.shipmentId).subscribe({
      next: (cn) => {
        this.cn.set(cn);
        this.pageTitleService.setTitle(cn.trackingNo ?? cn.cnNumber);
        this.ewayBillForm.patchValue({
          ewayBillNo: cn.ewayBillNo ?? '',
          ewayBillGeneratedDate: cn.ewayBillGeneratedDate ?? '',
          ewayBillValidUntil: cn.ewayBillValidUntil ?? '',
        });
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  private loadCharges(): void {
    this.billingService.getShipmentCharges(this.shipmentId).subscribe((charges) => this.charges.set(charges));
  }

  formatDateTime(value: string | null): string {
    if (!value) return '-';
    return new Date(value).toLocaleString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  downloadPdf(): void {
    const cn = this.cn();
    if (!cn || this.downloadingPdf()) return;

    this.downloadingPdf.set(true);
    this.opsService.getConsignmentNotePdf(this.shipmentId).subscribe({
      next: (blob) => {
        this.downloadingPdf.set(false);
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${cn.cnNumber.replace('/', '-')}.pdf`;
        link.click();
        URL.revokeObjectURL(url);
      },
      error: () => this.downloadingPdf.set(false),
    });
  }

  cancelConsignmentNote(): void {
    if (this.cancelForm.invalid) {
      this.cancelForm.markAllAsTouched();
      return;
    }

    const reason = this.cancelForm.getRawValue().cancelReason;

    this.confirmDialog
      .confirm({
        title: 'Cancel consignment note?',
        message: 'This cancels the consignment note - it cannot be undone.',
        confirmLabel: 'Cancel Note',
        destructive: true,
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.cancelling.set(true);
        this.opsService.cancelConsignmentNote(this.shipmentId, { cancelReason: reason }).subscribe({
          next: () => {
            this.cancelling.set(false);
            this.toast.success('Consignment note cancelled');
            this.load();
          },
          error: () => this.cancelling.set(false),
        });
      });
  }

  saveEwayBill(): void {
    if (this.ewayBillForm.invalid) {
      this.ewayBillForm.markAllAsTouched();
      return;
    }

    const value = this.ewayBillForm.getRawValue();
    this.savingEwayBill.set(true);

    this.opsService
      .updateConsignmentNoteEwayBill(this.shipmentId, {
        ewayBillNo: value.ewayBillNo,
        ewayBillGeneratedDate: value.ewayBillGeneratedDate,
        ewayBillValidUntil: value.ewayBillValidUntil,
      })
      .subscribe({
        next: () => {
          this.savingEwayBill.set(false);
          this.toast.success('E-way bill details saved');
          this.load();
        },
        error: () => this.savingEwayBill.set(false),
      });
  }

  // ---- Charges ----

  addCharge(): void {
    if (this.chargeForm.invalid) {
      this.chargeForm.markAllAsTouched();
      return;
    }

    const value = this.chargeForm.getRawValue();
    if (value.isOverridden && !value.overrideReason) {
      this.toast.error('An override reason is required when overriding a charge');
      return;
    }

    this.savingCharge.set(true);
    this.billingService
      .createShipmentCharge(this.shipmentId, {
        chargeType: value.chargeType,
        amount: value.amount!,
        description: value.description || undefined,
        isOverridden: value.isOverridden,
        overrideReason: value.isOverridden ? value.overrideReason : undefined,
      })
      .subscribe({
        next: () => {
          this.savingCharge.set(false);
          this.chargeForm.reset({ chargeType: '', amount: null, description: '', isOverridden: false, overrideReason: '' });
          this.toast.success('Charge added');
          this.loadCharges();
        },
        error: () => this.savingCharge.set(false),
      });
  }

  removeCharge(charge: ShipmentChargeModel): void {
    this.confirmDialog
      .confirm({ title: 'Remove charge?', message: `Remove this ${charge.chargeType} charge?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.billingService.deleteShipmentCharge(charge.id).subscribe({
          next: () => {
            this.toast.success('Charge removed');
            const next = new Set(this.selectedChargeIds());
            next.delete(charge.id);
            this.selectedChargeIds.set(next);
            this.loadCharges();
          },
        });
      });
  }

  isSelected(charge: ShipmentChargeModel): boolean {
    return this.selectedChargeIds().has(charge.id);
  }

  toggleCharge(charge: ShipmentChargeModel): void {
    if (charge.isInvoiced) return;
    const next = new Set(this.selectedChargeIds());
    if (next.has(charge.id)) {
      next.delete(charge.id);
    } else {
      next.add(charge.id);
    }
    this.selectedChargeIds.set(next);
  }

  generateInvoice(): void {
    this.generateInvoiceForm.markAllAsTouched();
    const cn = this.cn();

    if (this.generateInvoiceForm.invalid || this.selectedCharges().length === 0 || !cn) {
      return;
    }

    const value = this.generateInvoiceForm.getRawValue();
    this.generating.set(true);

    this.billingService
      .createInvoiceFromCharges({
        invoiceNo: value.invoiceNo,
        customerId: cn.billingPartyCustomerId,
        invoiceDate: value.invoiceDate,
        dueDate: value.dueDate,
        discountAmount: value.discountAmount ?? 0,
        taxAmount: value.taxAmount ?? 0,
        statusId: value.statusId!,
        shipmentChargeIds: this.selectedCharges().map((c) => c.id),
      })
      .subscribe({
        next: (invoiceId) => {
          this.generating.set(false);
          this.toast.success('Invoice generated successfully');
          this.selectedChargeIds.set(new Set());
          this.loadCharges();
          this.router.navigate(['/billing/invoices', invoiceId]);
        },
        error: () => this.generating.set(false),
      });
  }

  // ---- Delivery reconciliation ----

  private loadDeliveryLines(): void {
    this.opsService.getShipmentItemDeliveries(this.shipmentId).subscribe((lines) => this.deliveryLines.set(lines));
  }

  deliveryFormFor(line: ShipmentItemDeliveryLineModel): FormGroup<DeliveryFormModel> {
    let form = this.deliveryForms.get(line.shipmentItemId);
    if (!form) {
      form = new FormGroup<DeliveryFormModel>({
        deliveredQty: new FormControl<number | null>(line.delivery?.deliveredQty ?? line.quantity, {
          validators: [Validators.required, Validators.min(0)],
        }),
        shortQty: new FormControl<number | null>(line.delivery?.shortQty ?? 0, { validators: [Validators.min(0)] }),
        damagedQty: new FormControl<number | null>(line.delivery?.damagedQty ?? 0, { validators: [Validators.min(0)] }),
        remarks: new FormControl(line.delivery?.remarks ?? '', { nonNullable: true }),
      });
      if (line.delivery) form.disable();
      this.deliveryForms.set(line.shipmentItemId, form);
    }
    return form;
  }

  isEditingDelivery(shipmentItemId: number): boolean {
    return this.editingDeliveryIds().has(shipmentItemId);
  }

  isSavingDelivery(shipmentItemId: number): boolean {
    return this.savingDeliveryIds().has(shipmentItemId);
  }

  toggleEditDelivery(shipmentItemId: number): void {
    const form = this.deliveryForms.get(shipmentItemId);
    const editing = new Set(this.editingDeliveryIds());
    if (editing.has(shipmentItemId)) {
      editing.delete(shipmentItemId);
      form?.disable();
    } else {
      editing.add(shipmentItemId);
      form?.enable();
    }
    this.editingDeliveryIds.set(editing);
  }

  onDeliveryPhotosSelected(shipmentItemId: number, event: Event): void {
    const input = event.target as HTMLInputElement;
    this.selectedPhotosByItem.set(shipmentItemId, input.files ? Array.from(input.files) : []);
  }

  private setSaving(shipmentItemId: number, saving: boolean): void {
    const ids = new Set(this.savingDeliveryIds());
    if (saving) ids.add(shipmentItemId);
    else ids.delete(shipmentItemId);
    this.savingDeliveryIds.set(ids);
  }

  recordDelivery(line: ShipmentItemDeliveryLineModel): void {
    const form = this.deliveryFormFor(line);
    if (form.invalid) {
      form.markAllAsTouched();
      return;
    }

    const value = form.getRawValue();
    const formData = new FormData();
    formData.append('deliveredQty', String(value.deliveredQty));
    formData.append('shortQty', String(value.shortQty ?? 0));
    formData.append('damagedQty', String(value.damagedQty ?? 0));
    if (value.remarks) formData.append('remarks', value.remarks);
    for (const photo of this.selectedPhotosByItem.get(line.shipmentItemId) ?? []) {
      formData.append('photos', photo, photo.name);
    }

    this.setSaving(line.shipmentItemId, true);
    this.opsService.createShipmentItemDelivery(line.shipmentItemId, formData).subscribe({
      next: () => {
        this.setSaving(line.shipmentItemId, false);
        this.deliveryForms.delete(line.shipmentItemId);
        this.selectedPhotosByItem.delete(line.shipmentItemId);
        this.toast.success('Delivery recorded');
        this.loadDeliveryLines();
      },
      error: () => this.setSaving(line.shipmentItemId, false),
    });
  }

  saveDeliveryEdit(line: ShipmentItemDeliveryLineModel): void {
    const form = this.deliveryFormFor(line);
    if (form.invalid || !line.delivery) {
      form.markAllAsTouched();
      return;
    }

    const value = form.getRawValue();
    this.setSaving(line.shipmentItemId, true);

    this.opsService
      .updateShipmentItemDelivery(line.delivery.deliveryId, {
        deliveredQty: value.deliveredQty!,
        shortQty: value.shortQty ?? 0,
        damagedQty: value.damagedQty ?? 0,
        remarks: value.remarks || undefined,
      })
      .subscribe({
        next: () => {
          this.setSaving(line.shipmentItemId, false);
          this.toggleEditDelivery(line.shipmentItemId);
          this.deliveryForms.delete(line.shipmentItemId);
          this.toast.success('Delivery updated');
          this.loadDeliveryLines();
        },
        error: () => this.setSaving(line.shipmentItemId, false),
      });
  }

  addDeliveryPhotos(line: ShipmentItemDeliveryLineModel): void {
    if (!line.delivery) return;
    const photos = this.selectedPhotosByItem.get(line.shipmentItemId) ?? [];
    if (photos.length === 0) {
      this.toast.error('Choose one or more photos first');
      return;
    }

    this.setSaving(line.shipmentItemId, true);
    let remaining = photos.length;
    for (const photo of photos) {
      const formData = new FormData();
      formData.append('photo', photo, photo.name);
      this.opsService.addShipmentItemDeliveryPhoto(line.delivery.deliveryId, formData).subscribe({
        next: () => {
          remaining -= 1;
          if (remaining === 0) {
            this.setSaving(line.shipmentItemId, false);
            this.selectedPhotosByItem.delete(line.shipmentItemId);
            this.toast.success('Photos added');
            this.loadDeliveryLines();
          }
        },
        error: () => this.setSaving(line.shipmentItemId, false),
      });
    }
  }

  // ---- Claims ----

  private loadClaims(): void {
    this.claimService.getClaims({ shipmentId: this.shipmentId }, 1, 50).subscribe((result) => this.claims.set(result.items));
  }

  raiseClaim(): void {
    if (this.claimForm.invalid) {
      this.claimForm.markAllAsTouched();
      return;
    }

    const raisedStatus = this.claimStatusOptions().find((s) => s.code === 'RAISED');
    if (!raisedStatus) {
      this.toast.error('Claim status codes are not configured');
      return;
    }

    const value = this.claimForm.getRawValue();
    this.savingClaim.set(true);

    this.claimService
      .createClaim({
        shipmentId: this.shipmentId,
        claimantName: value.claimantName,
        claimantPhone: value.claimantPhone || undefined,
        amountClaimed: value.amountClaimed!,
        statusId: raisedStatus.id,
        notes: value.notes || undefined,
      })
      .subscribe({
        next: (claimId) => {
          this.savingClaim.set(false);
          this.toast.success('Claim raised');
          this.claimForm.reset({ claimantName: '', claimantPhone: '', amountClaimed: null, notes: '' });
          this.loadClaims();
          this.router.navigate(['/claims', claimId]);
        },
        error: () => this.savingClaim.set(false),
      });
  }
}
