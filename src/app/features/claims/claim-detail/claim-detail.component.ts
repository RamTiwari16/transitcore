import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { ClaimService } from '../../../services/claim.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { CLAIM_SETTLEMENT_METHODS, ClaimDetailModel } from '../../../models/claim.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { InrPipe } from '../../../shared/pipes/inr.pipe';

interface EditFormModel {
  claimantName: FormControl<string>;
  claimantPhone: FormControl<string>;
  amountClaimed: FormControl<number | null>;
  notes: FormControl<string>;
}

interface StatusFormModel {
  statusId: FormControl<number | null>;
  notes: FormControl<string>;
}

interface SettleFormModel {
  settledAmount: FormControl<number | null>;
  settlementMethod: FormControl<string>;
  notes: FormControl<string>;
}

@Component({
  selector: 'app-claim-detail',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatProgressSpinnerModule,
    InrPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './claim-detail.component.html',
  styleUrl: './claim-detail.component.scss',
})
export class ClaimDetailComponent {
  readonly settlementMethods = CLAIM_SETTLEMENT_METHODS;

  private readonly claimService = inject(ClaimService);
  private readonly lookupService = inject(LookupService);
  private readonly toast = inject(ToastService);
  private readonly route = inject(ActivatedRoute);
  private readonly pageTitleService = inject(PageTitleService);
  private readonly claimId = Number(this.route.snapshot.paramMap.get('id'));

  readonly claim = signal<ClaimDetailModel | null>(null);
  readonly loading = signal(true);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly savingEdit = signal(false);
  readonly savingStatus = signal(false);
  readonly savingSettlement = signal(false);

  // Settling has its own dedicated action - the plain status dropdown only
  // offers the non-settlement transitions (matches usp_UpdateClaimStatus
  // rejecting a direct jump to Settled).
  readonly nonSettlementStatusOptions = computed(() =>
    this.statusOptions().filter((s) => s.code !== 'SETTLED'),
  );

  readonly isClosed = computed(() => {
    const claim = this.claim();
    return claim?.statusName === 'Settled' || claim?.statusName === 'Rejected';
  });

  readonly editForm = new FormGroup<EditFormModel>({
    claimantName: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    claimantPhone: new FormControl('', { nonNullable: true }),
    amountClaimed: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
    notes: new FormControl('', { nonNullable: true }),
  });

  readonly statusForm = new FormGroup<StatusFormModel>({
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    notes: new FormControl('', { nonNullable: true }),
  });

  readonly settleForm = new FormGroup<SettleFormModel>({
    settledAmount: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0)] }),
    settlementMethod: new FormControl('InvoiceDeduction', { nonNullable: true, validators: [Validators.required] }),
    notes: new FormControl('', { nonNullable: true }),
  });

  constructor() {
    effect(() => this.pageTitleService.setTitle(this.claim()?.trackingNo ?? null));
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.lookupService.getStatusCodes('Claim').subscribe((s) => this.statusOptions.set(s));
    this.load();
  }

  private load(): void {
    this.loading.set(true);
    this.claimService.getClaimById(this.claimId).subscribe({
      next: (claim) => {
        this.claim.set(claim);
        this.editForm.patchValue({
          claimantName: claim.claimantName,
          claimantPhone: claim.claimantPhone ?? '',
          amountClaimed: claim.amountClaimed,
          notes: claim.notes ?? '',
        });
        this.settleForm.patchValue({ settledAmount: claim.amountClaimed });
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  formatDateTime(value: string): string {
    return new Date(value).toLocaleString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  saveEdit(): void {
    if (this.editForm.invalid) {
      this.editForm.markAllAsTouched();
      return;
    }

    const value = this.editForm.getRawValue();
    this.savingEdit.set(true);

    this.claimService
      .updateClaim({
        claimId: this.claimId,
        claimantName: value.claimantName,
        claimantPhone: value.claimantPhone || undefined,
        amountClaimed: value.amountClaimed!,
        notes: value.notes || undefined,
      })
      .subscribe({
        next: () => {
          this.savingEdit.set(false);
          this.toast.success('Claim updated');
          this.load();
        },
        error: () => this.savingEdit.set(false),
      });
  }

  updateStatus(): void {
    if (this.statusForm.invalid) {
      this.statusForm.markAllAsTouched();
      return;
    }

    const value = this.statusForm.getRawValue();
    this.savingStatus.set(true);

    this.claimService
      .updateClaimStatus({ claimId: this.claimId, statusId: value.statusId!, notes: value.notes || undefined })
      .subscribe({
        next: () => {
          this.savingStatus.set(false);
          this.toast.success('Claim status updated');
          this.statusForm.reset({ statusId: null, notes: '' });
          this.load();
        },
        error: () => this.savingStatus.set(false),
      });
  }

  settleClaim(): void {
    if (this.settleForm.invalid) {
      this.settleForm.markAllAsTouched();
      return;
    }

    const value = this.settleForm.getRawValue();
    this.savingSettlement.set(true);

    this.claimService
      .settleClaim({
        claimId: this.claimId,
        settledAmount: value.settledAmount!,
        settlementMethod: value.settlementMethod,
        notes: value.notes || undefined,
      })
      .subscribe({
        next: () => {
          this.savingSettlement.set(false);
          this.toast.success('Claim settled');
          this.load();
        },
        error: () => this.savingSettlement.set(false),
      });
  }
}
