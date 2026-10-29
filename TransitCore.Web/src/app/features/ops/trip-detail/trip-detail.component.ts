import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  effect,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatTabsModule } from '@angular/material/tabs';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatTooltipModule } from '@angular/material/tooltip';
import { OpsService } from '../../../services/ops.service';
import { LookupService } from '../../../services/lookup.service';
import { VendorService } from '../../../services/vendor.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import {
  ProofOfDeliveryModel,
  RouteStopModel,
  ShipmentModel,
  TripAdvanceModel,
  TripCapacityCheckModel,
  TripCostSummaryModel,
  TripDetailModel,
  TripDocumentModel,
  TripExpenseModel,
  TripIncidentModel,
  TripStopShipmentModel,
  TripStopVisitModel,
  TripDispatchComplianceCheckModel,
} from '../../../models/ops.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { VendorAdvanceModel, VendorDeductionModel } from '../../../models/vendor.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { environment } from '../../../../environments/environment';

interface ExpenseFormModel {
  expenseType: FormControl<string>;
  amount: FormControl<number | null>;
  expenseDate: FormControl<string>;
  notes: FormControl<string>;
}

interface AdvanceFormModel {
  amount: FormControl<number | null>;
  advanceDate: FormControl<string>;
  notes: FormControl<string>;
}

interface VendorAdvanceFormModel {
  amount: FormControl<number | null>;
  advanceDate: FormControl<string>;
  remarks: FormControl<string>;
}

interface VendorDeductionFormModel {
  amount: FormControl<number | null>;
  reason: FormControl<string>;
  deductionDate: FormControl<string>;
}

interface VendorBillFormModel {
  billNo: FormControl<string>;
  billDate: FormControl<string>;
  dueDate: FormControl<string>;
  statusId: FormControl<number | null>;
}

interface KmFormModel {
  loadedKm: FormControl<number | null>;
  emptyKm: FormControl<number | null>;
}

interface PodFormModel {
  receiverName: FormControl<string>;
  receiverPhone: FormControl<string>;
  deliveredAt: FormControl<string>;
  notes: FormControl<string>;
}

interface DocumentFormModel {
  documentType: FormControl<string>;
}

interface IncidentFormModel {
  incidentType: FormControl<string>;
  description: FormControl<string>;
}

interface StopShipmentFormModel {
  shipmentId: FormControl<number | null>;
  action: FormControl<string>;
  stopType: FormControl<string>;
  routeStopId: FormControl<number | null>;
}

interface StopVisitFormModel {
  stopType: FormControl<string>;
  routeStopId: FormControl<number | null>;
  arrivedAt: FormControl<string>;
  departedAt: FormControl<string>;
}

function nowForDatetimeLocal(): string {
  const now = new Date();
  now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
  return now.toISOString().slice(0, 16);
}

@Component({
  selector: 'app-trip-detail',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatTabsModule,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatTooltipModule,
    EmptyStateComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './trip-detail.component.html',
  styleUrl: './trip-detail.component.scss',
})
export class TripDetailComponent {
  readonly fileBaseUrl = environment.apiUrl;

  readonly trip = signal<TripDetailModel | null>(null);
  readonly loading = signal(true);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly pendingStatusId = signal<number | null>(null);

  readonly capacityCheck = signal<TripCapacityCheckModel | null>(null);
  readonly complianceChecks = signal<TripDispatchComplianceCheckModel[]>([]);

  readonly expenses = signal<TripExpenseModel[]>([]);
  readonly advances = signal<TripAdvanceModel[]>([]);
  readonly costSummary = signal<TripCostSummaryModel | null>(null);
  readonly savingExpense = signal(false);
  readonly savingAdvance = signal(false);

  readonly vendorAdvances = signal<VendorAdvanceModel[]>([]);
  readonly vendorDeductions = signal<VendorDeductionModel[]>([]);
  readonly vendorBillStatusOptions = signal<StatusCodeModel[]>([]);
  readonly savingVendorAdvance = signal(false);
  readonly savingVendorDeduction = signal(false);
  readonly creatingVendorBill = signal(false);

  readonly pod = signal<ProofOfDeliveryModel | null>(null);
  readonly podLoaded = signal(false);
  readonly savingPod = signal(false);
  readonly hasSignature = signal(false);
  private selectedPhotos: File[] = [];
  readonly selectedPhotoCount = signal(0);

  readonly documents = signal<TripDocumentModel[]>([]);
  readonly savingDocument = signal(false);
  private selectedDocumentFile: File | null = null;
  readonly selectedDocumentName = signal<string | null>(null);

  readonly incidents = signal<TripIncidentModel[]>([]);
  readonly savingIncident = signal(false);

  readonly stopShipments = signal<TripStopShipmentModel[]>([]);
  // Only shipments already assigned to this trip are loadable/unloadable
  // against it - there's no server-side "shipments for trip X" filter, so
  // this filters the full shipment list client-side.
  readonly tripShipments = signal<ShipmentModel[]>([]);
  readonly routeStops = signal<RouteStopModel[]>([]);
  readonly savingStopShipment = signal(false);

  readonly stopVisits = signal<TripStopVisitModel[]>([]);
  readonly savingStopVisit = signal(false);

  readonly savingKm = signal(false);

  private readonly route = inject(ActivatedRoute);
  private readonly pageTitleService = inject(PageTitleService);
  private readonly opsService = inject(OpsService);
  private readonly lookupService = inject(LookupService);
  private readonly vendorService = inject(VendorService);
  private readonly router = inject(Router);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly toast = inject(ToastService);
  private readonly tripId = Number(this.route.snapshot.paramMap.get('id'));

  private readonly signatureCanvas = viewChild<ElementRef<HTMLCanvasElement>>('signatureCanvas');
  private signatureCtx: CanvasRenderingContext2D | null = null;
  private isDrawing = false;

  readonly expenseForm = new FormGroup<ExpenseFormModel>({
    expenseType: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    amount: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
    expenseDate: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    notes: new FormControl('', { nonNullable: true }),
  });

  readonly advanceForm = new FormGroup<AdvanceFormModel>({
    amount: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
    advanceDate: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    notes: new FormControl('', { nonNullable: true }),
  });

  readonly vendorAdvanceForm = new FormGroup<VendorAdvanceFormModel>({
    amount: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
    advanceDate: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    remarks: new FormControl('', { nonNullable: true }),
  });

  readonly vendorDeductionForm = new FormGroup<VendorDeductionFormModel>({
    amount: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
    reason: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    deductionDate: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });

  readonly vendorBillForm = new FormGroup<VendorBillFormModel>({
    billNo: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    billDate: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    dueDate: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
  });

  readonly podForm = new FormGroup<PodFormModel>({
    receiverName: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    receiverPhone: new FormControl('', { nonNullable: true }),
    deliveredAt: new FormControl(nowForDatetimeLocal(), { nonNullable: true, validators: [Validators.required] }),
    notes: new FormControl('', { nonNullable: true }),
  });

  readonly documentForm = new FormGroup<DocumentFormModel>({
    documentType: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });

  readonly incidentForm = new FormGroup<IncidentFormModel>({
    incidentType: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    description: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });

  readonly stopShipmentForm = new FormGroup<StopShipmentFormModel>({
    shipmentId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    action: new FormControl('Load', { nonNullable: true, validators: [Validators.required] }),
    stopType: new FormControl('Origin', { nonNullable: true, validators: [Validators.required] }),
    routeStopId: new FormControl<number | null>(null),
  });

  readonly stopVisitForm = new FormGroup<StopVisitFormModel>({
    stopType: new FormControl('Origin', { nonNullable: true, validators: [Validators.required] }),
    routeStopId: new FormControl<number | null>(null),
    arrivedAt: new FormControl('', { nonNullable: true }),
    departedAt: new FormControl('', { nonNullable: true }),
  });

  readonly kmForm = new FormGroup<KmFormModel>({
    loadedKm: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
    emptyKm: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
  });

  constructor() {
    effect(() => this.pageTitleService.setTitle(this.trip()?.routeName ?? null));
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.lookupService.getStatusCodes('Trip').subscribe((s) => this.statusOptions.set(s));
    this.lookupService.getStatusCodes('VendorBill').subscribe((s) => this.vendorBillStatusOptions.set(s));
    this.load();
    this.loadCapacityCheck();
    this.loadComplianceChecks();
    this.loadExpenses();
    this.loadAdvances();
    this.loadCostSummary();
    this.loadProofOfDelivery();
    this.loadDocuments();
    this.loadIncidents();
    this.loadStopShipments();
    this.loadStopVisits();
    this.opsService.getShipments({}).subscribe((shipments) =>
      this.tripShipments.set(shipments.filter((s) => s.tripId === this.tripId)),
    );

    // The canvas only exists once podLoaded() resolves true AND there's no
    // existing POD (it's behind that @if in the template) - a plain
    // AfterViewInit hook runs once, immediately, well before that async
    // state settles, so it would find no canvas and never initialize a
    // context. This effect re-runs whenever the viewChild signal itself
    // changes, which is exactly when the canvas actually appears.
    effect(() => {
      const canvas = this.signatureCanvas()?.nativeElement;
      if (!canvas) return;
      this.signatureCtx = canvas.getContext('2d');
      if (this.signatureCtx) {
        this.signatureCtx.strokeStyle = '#1a1a1a';
        this.signatureCtx.lineWidth = 2;
        this.signatureCtx.lineCap = 'round';
      }
    });
  }

  private load(): void {
    this.loading.set(true);
    this.opsService.getTripById(this.tripId).subscribe({
      next: (trip) => {
        this.trip.set(trip);
        this.pendingStatusId.set(trip.statusId);
        this.kmForm.patchValue({ loadedKm: trip.loadedKm, emptyKm: trip.emptyKm });
        this.loading.set(false);
        this.opsService.getRouteStops(trip.routeId).subscribe((stops) => this.routeStops.set(stops));
        if (trip.ownershipType === 'Hired') {
          this.loadVendorAdvances();
          this.loadVendorDeductions();
        }
      },
      error: () => this.loading.set(false),
    });
  }

  private loadCapacityCheck(): void {
    this.opsService.getTripCapacityCheck(this.tripId).subscribe((check) => this.capacityCheck.set(check));
  }

  private loadComplianceChecks(): void {
    this.opsService.getTripDispatchCompliance(this.tripId).subscribe((checks) => this.complianceChecks.set(checks));
  }

  applyStatusChange(): void {
    const trip = this.trip();
    const newStatusId = this.pendingStatusId();
    if (!trip || newStatusId === null || newStatusId === trip.statusId) {
      return;
    }

    const newStatusName = this.statusOptions().find((s) => s.id === newStatusId)?.name ?? 'selected status';

    this.confirmDialog
      .confirm({
        title: 'Update trip status?',
        message: `Change this trip's status to "${newStatusName}"?`,
        confirmLabel: 'Update status',
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;

        this.opsService.updateTripStatus({ tripId: trip.id, statusId: newStatusId }).subscribe({
          next: () => {
            this.toast.success('Trip status updated');
            this.load();
          },
        });
      });
  }

  saveKm(): void {
    if (this.kmForm.invalid) {
      this.kmForm.markAllAsTouched();
      return;
    }

    const value = this.kmForm.getRawValue();
    this.savingKm.set(true);

    this.opsService.updateTripKm(this.tripId, { loadedKm: value.loadedKm!, emptyKm: value.emptyKm! }).subscribe({
      next: () => {
        this.savingKm.set(false);
        this.toast.success('Trip km updated');
        this.load();
      },
      error: () => this.savingKm.set(false),
    });
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

  // ---- Expenses ----

  private loadExpenses(): void {
    this.opsService.getTripExpenses(this.tripId).subscribe((expenses) => this.expenses.set(expenses));
  }

  private loadCostSummary(): void {
    this.opsService.getTripCostSummary(this.tripId).subscribe((summary) => this.costSummary.set(summary));
  }

  addExpense(): void {
    if (this.expenseForm.invalid) {
      this.expenseForm.markAllAsTouched();
      return;
    }

    const value = this.expenseForm.getRawValue();
    this.savingExpense.set(true);

    this.opsService
      .createTripExpense(this.tripId, {
        expenseType: value.expenseType,
        amount: value.amount!,
        expenseDate: value.expenseDate,
        notes: value.notes || undefined,
      })
      .subscribe({
        next: () => {
          this.savingExpense.set(false);
          this.expenseForm.reset({ expenseType: '', amount: null, expenseDate: '', notes: '' });
          this.toast.success('Expense added');
          this.loadExpenses();
          this.loadCostSummary();
        },
        error: () => this.savingExpense.set(false),
      });
  }

  removeExpense(expense: TripExpenseModel): void {
    this.confirmDialog
      .confirm({ title: 'Remove expense?', message: `Remove this ${expense.expenseType} expense?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.opsService.deleteTripExpense(expense.id).subscribe({
          next: () => {
            this.toast.success('Expense removed');
            this.loadExpenses();
            this.loadCostSummary();
          },
        });
      });
  }

  // ---- Advances ----

  private loadAdvances(): void {
    this.opsService.getTripAdvances(this.tripId).subscribe((advances) => this.advances.set(advances));
  }

  addAdvance(): void {
    if (this.advanceForm.invalid) {
      this.advanceForm.markAllAsTouched();
      return;
    }

    const value = this.advanceForm.getRawValue();
    this.savingAdvance.set(true);

    this.opsService
      .createTripAdvance(this.tripId, {
        amount: value.amount!,
        advanceDate: value.advanceDate,
        notes: value.notes || undefined,
      })
      .subscribe({
        next: () => {
          this.savingAdvance.set(false);
          this.advanceForm.reset({ amount: null, advanceDate: '', notes: '' });
          this.toast.success('Advance recorded');
          this.loadAdvances();
          this.loadCostSummary();
        },
        error: () => this.savingAdvance.set(false),
      });
  }

  removeAdvance(advance: TripAdvanceModel): void {
    this.confirmDialog
      .confirm({ title: 'Remove advance?', message: 'Remove this advance record?', confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.opsService.deleteTripAdvance(advance.id).subscribe({
          next: () => {
            this.toast.success('Advance removed');
            this.loadAdvances();
            this.loadCostSummary();
          },
        });
      });
  }

  // ---- Vendor advances / deductions (Hired trips) ----

  private loadVendorAdvances(): void {
    this.vendorService.getVendorAdvances(this.tripId).subscribe((advances) => this.vendorAdvances.set(advances));
  }

  private loadVendorDeductions(): void {
    this.vendorService.getVendorDeductions(this.tripId).subscribe((deductions) => this.vendorDeductions.set(deductions));
  }

  addVendorAdvance(): void {
    const trip = this.trip();
    if (!trip?.vendorId || this.vendorAdvanceForm.invalid) {
      this.vendorAdvanceForm.markAllAsTouched();
      return;
    }

    const value = this.vendorAdvanceForm.getRawValue();
    this.savingVendorAdvance.set(true);

    this.vendorService
      .createVendorAdvance(this.tripId, {
        vendorId: trip.vendorId,
        amount: value.amount!,
        advanceDate: value.advanceDate,
        remarks: value.remarks || undefined,
      })
      .subscribe({
        next: () => {
          this.savingVendorAdvance.set(false);
          this.vendorAdvanceForm.reset({ amount: null, advanceDate: '', remarks: '' });
          this.toast.success('Vendor advance recorded');
          this.loadVendorAdvances();
        },
        error: () => this.savingVendorAdvance.set(false),
      });
  }

  removeVendorAdvance(advance: VendorAdvanceModel): void {
    this.confirmDialog
      .confirm({ title: 'Remove vendor advance?', message: 'Remove this advance record?', confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.vendorService.deleteVendorAdvance(advance.id).subscribe({
          next: () => {
            this.toast.success('Advance removed');
            this.loadVendorAdvances();
          },
        });
      });
  }

  addVendorDeduction(): void {
    const trip = this.trip();
    if (!trip?.vendorId || this.vendorDeductionForm.invalid) {
      this.vendorDeductionForm.markAllAsTouched();
      return;
    }

    const value = this.vendorDeductionForm.getRawValue();
    this.savingVendorDeduction.set(true);

    this.vendorService
      .createVendorDeduction(this.tripId, {
        vendorId: trip.vendorId,
        amount: value.amount!,
        reason: value.reason,
        deductionDate: value.deductionDate,
      })
      .subscribe({
        next: () => {
          this.savingVendorDeduction.set(false);
          this.vendorDeductionForm.reset({ amount: null, reason: '', deductionDate: '' });
          this.toast.success('Vendor deduction recorded');
          this.loadVendorDeductions();
        },
        error: () => this.savingVendorDeduction.set(false),
      });
  }

  removeVendorDeduction(deduction: VendorDeductionModel): void {
    this.confirmDialog
      .confirm({ title: 'Remove vendor deduction?', message: 'Remove this deduction record?', confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.vendorService.deleteVendorDeduction(deduction.id).subscribe({
          next: () => {
            this.toast.success('Deduction removed');
            this.loadVendorDeductions();
          },
        });
      });
  }

  createVendorBill(): void {
    if (this.vendorBillForm.invalid) {
      this.vendorBillForm.markAllAsTouched();
      return;
    }

    const value = this.vendorBillForm.getRawValue();
    this.creatingVendorBill.set(true);

    this.vendorService
      .createVendorBill(this.tripId, {
        billNo: value.billNo,
        billDate: value.billDate,
        dueDate: value.dueDate,
        statusId: value.statusId!,
      })
      .subscribe({
        next: (vendorBillId) => {
          this.creatingVendorBill.set(false);
          this.toast.success('Vendor bill created');
          this.router.navigate(['/vendors/bills', vendorBillId]);
        },
        error: () => this.creatingVendorBill.set(false),
      });
  }

  // ---- Proof of delivery ----

  private loadProofOfDelivery(): void {
    // Not-yet-delivered is a 200 with null data (see the controller's
    // comment), not a 404 - so this genuinely only needs a next handler now.
    this.opsService.getProofOfDelivery(this.tripId).subscribe((pod) => {
      this.pod.set(pod);
      this.podLoaded.set(true);
    });
  }

  onSignatureStart(event: PointerEvent): void {
    if (!this.signatureCtx) return;
    this.isDrawing = true;
    const rect = (event.target as HTMLElement).getBoundingClientRect();
    this.signatureCtx.beginPath();
    this.signatureCtx.moveTo(event.clientX - rect.left, event.clientY - rect.top);
  }

  onSignatureMove(event: PointerEvent): void {
    if (!this.isDrawing || !this.signatureCtx) return;
    const rect = (event.target as HTMLElement).getBoundingClientRect();
    this.signatureCtx.lineTo(event.clientX - rect.left, event.clientY - rect.top);
    this.signatureCtx.stroke();
    this.hasSignature.set(true);
  }

  onSignatureEnd(): void {
    this.isDrawing = false;
  }

  clearSignature(): void {
    const canvas = this.signatureCanvas()?.nativeElement;
    if (!canvas || !this.signatureCtx) return;
    this.signatureCtx.clearRect(0, 0, canvas.width, canvas.height);
    this.hasSignature.set(false);
  }

  onPhotosSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.selectedPhotos = input.files ? Array.from(input.files) : [];
    this.selectedPhotoCount.set(this.selectedPhotos.length);
  }

  submitProofOfDelivery(): void {
    if (this.podForm.invalid) {
      this.podForm.markAllAsTouched();
      return;
    }

    const value = this.podForm.getRawValue();
    const formData = new FormData();
    formData.append('receiverName', value.receiverName);
    if (value.receiverPhone) formData.append('receiverPhone', value.receiverPhone);
    // Sent as the plain local wall-clock string ("2026-09-15T10:00" -> add
    // seconds), not converted through Date/toISOString() - that round-trips
    // through the browser's local timezone on the way out and gets
    // re-interpreted as local again with no offset info on the way back in,
    // silently shifting the displayed time (same class of bug already
    // avoided in trip-form's toDatetimeLocal()).
    formData.append('deliveredAt', `${value.deliveredAt}:00`);
    if (value.notes) formData.append('notes', value.notes);

    const canvas = this.signatureCanvas()?.nativeElement;
    this.savingPod.set(true);

    const finish = () => {
      for (const photo of this.selectedPhotos) {
        formData.append('photos', photo, photo.name);
      }

      this.opsService.createProofOfDelivery(this.tripId, formData).subscribe({
        next: () => {
          this.savingPod.set(false);
          this.toast.success('Proof of delivery recorded');
          this.loadProofOfDelivery();
        },
        error: () => this.savingPod.set(false),
      });
    };

    if (canvas && this.hasSignature()) {
      canvas.toBlob((blob) => {
        if (blob) formData.append('signature', blob, 'signature.png');
        finish();
      }, 'image/png');
    } else {
      finish();
    }
  }

  // ---- Documents ----

  private loadDocuments(): void {
    this.opsService.getTripDocuments(this.tripId).subscribe((documents) => this.documents.set(documents));
  }

  onDocumentFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.selectedDocumentFile = input.files?.[0] ?? null;
    this.selectedDocumentName.set(this.selectedDocumentFile?.name ?? null);
  }

  addDocument(): void {
    if (this.documentForm.invalid || !this.selectedDocumentFile) {
      this.documentForm.markAllAsTouched();
      if (!this.selectedDocumentFile) this.toast.error('Choose a file to upload');
      return;
    }

    const formData = new FormData();
    formData.append('documentType', this.documentForm.getRawValue().documentType);
    formData.append('file', this.selectedDocumentFile, this.selectedDocumentFile.name);

    this.savingDocument.set(true);
    this.opsService.createTripDocument(this.tripId, formData).subscribe({
      next: () => {
        this.savingDocument.set(false);
        this.documentForm.reset({ documentType: '' });
        this.selectedDocumentFile = null;
        this.selectedDocumentName.set(null);
        this.toast.success('Document uploaded');
        this.loadDocuments();
      },
      error: () => this.savingDocument.set(false),
    });
  }

  removeDocument(document: TripDocumentModel): void {
    this.confirmDialog
      .confirm({ title: 'Remove document?', message: `Remove "${document.fileName}"?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.opsService.deleteTripDocument(document.id).subscribe({
          next: () => {
            this.toast.success('Document removed');
            this.loadDocuments();
          },
        });
      });
  }

  // ---- Incidents ----

  private loadIncidents(): void {
    this.opsService.getTripIncidents(this.tripId).subscribe((incidents) => this.incidents.set(incidents));
  }

  addIncident(): void {
    if (this.incidentForm.invalid) {
      this.incidentForm.markAllAsTouched();
      return;
    }

    const value = this.incidentForm.getRawValue();
    this.savingIncident.set(true);

    this.opsService
      .createTripIncident(this.tripId, { incidentType: value.incidentType, description: value.description })
      .subscribe({
        next: () => {
          this.savingIncident.set(false);
          this.incidentForm.reset({ incidentType: '', description: '' });
          this.toast.success('Incident reported');
          this.loadIncidents();
        },
        error: () => this.savingIncident.set(false),
      });
  }

  removeIncident(incident: TripIncidentModel): void {
    this.confirmDialog
      .confirm({ title: 'Remove incident report?', message: 'Remove this incident report?', confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.opsService.deleteTripIncident(incident.id).subscribe({
          next: () => {
            this.toast.success('Incident removed');
            this.loadIncidents();
          },
        });
      });
  }

  // ---- Stop shipments (load/unload events) ----

  private loadStopShipments(): void {
    this.opsService.getTripStopShipments(this.tripId).subscribe((events) => this.stopShipments.set(events));
  }

  addStopShipment(): void {
    if (this.stopShipmentForm.invalid) {
      this.stopShipmentForm.markAllAsTouched();
      return;
    }

    const value = this.stopShipmentForm.getRawValue();
    if (value.stopType === 'IntermediateStop' && value.routeStopId === null) {
      this.toast.error('Choose the intermediate stop');
      return;
    }

    this.savingStopShipment.set(true);
    this.opsService
      .createTripStopShipment(this.tripId, {
        shipmentId: value.shipmentId!,
        action: value.action,
        stopType: value.stopType,
        routeStopId: value.stopType === 'IntermediateStop' ? value.routeStopId! : undefined,
      })
      .subscribe({
        next: () => {
          this.savingStopShipment.set(false);
          this.stopShipmentForm.patchValue({ shipmentId: null, routeStopId: null });
          this.toast.success(`${value.action} recorded`);
          this.loadStopShipments();
        },
        error: () => this.savingStopShipment.set(false),
      });
  }

  removeStopShipment(event: TripStopShipmentModel): void {
    this.confirmDialog
      .confirm({ title: 'Remove this event?', message: `Remove this ${event.action.toLowerCase()} record?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.opsService.deleteTripStopShipment(event.id).subscribe({
          next: () => {
            this.toast.success('Event removed');
            this.loadStopShipments();
          },
        });
      });
  }

  // ---- Stop visits (detention tracking) ----

  private loadStopVisits(): void {
    this.opsService.getTripStopVisits(this.tripId).subscribe((visits) => this.stopVisits.set(visits));
  }

  recordStopVisit(): void {
    if (this.stopVisitForm.invalid) {
      this.stopVisitForm.markAllAsTouched();
      return;
    }

    const value = this.stopVisitForm.getRawValue();
    if (value.stopType === 'IntermediateStop' && value.routeStopId === null) {
      this.toast.error('Choose the intermediate stop');
      return;
    }

    this.savingStopVisit.set(true);
    this.opsService
      .upsertTripStopVisit(this.tripId, {
        stopType: value.stopType,
        routeStopId: value.stopType === 'IntermediateStop' ? value.routeStopId! : undefined,
        arrivedAt: value.arrivedAt ? `${value.arrivedAt}:00` : undefined,
        departedAt: value.departedAt ? `${value.departedAt}:00` : undefined,
      })
      .subscribe({
        next: () => {
          this.savingStopVisit.set(false);
          this.toast.success('Visit recorded');
          this.loadStopVisits();
        },
        error: () => this.savingStopVisit.set(false),
      });
  }
}
