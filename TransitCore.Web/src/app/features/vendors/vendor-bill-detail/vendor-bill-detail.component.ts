import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
import { VendorService } from '../../../services/vendor.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { VendorBillDetailModel, VendorPaymentModel } from '../../../models/vendor.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { InrPipe } from '../../../shared/pipes/inr.pipe';
import { toLocalIsoDate } from '../../../shared/util/date';

interface PaymentFormModel {
  paymentDate: FormControl<string>;
  amount: FormControl<number | null>;
  method: FormControl<string>;
  referenceNo: FormControl<string>;
}

const PAYMENT_METHODS = ['Cash', 'Bank Transfer', 'Cheque', 'UPI', 'Card'];

@Component({
  selector: 'app-vendor-bill-detail',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatProgressSpinnerModule,
    MatTooltipModule,
    EmptyStateComponent,
    InrPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './vendor-bill-detail.component.html',
  styleUrl: './vendor-bill-detail.component.scss',
})
export class VendorBillDetailComponent {
  private readonly vendorService = inject(VendorService);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly toast = inject(ToastService);
  private readonly route = inject(ActivatedRoute);
  private readonly pageTitleService = inject(PageTitleService);
  private readonly vendorBillId = Number(this.route.snapshot.paramMap.get('id'));

  readonly paymentMethods = PAYMENT_METHODS;

  readonly bill = signal<VendorBillDetailModel | null>(null);
  readonly loading = signal(true);
  readonly savingPayment = signal(false);

  readonly balanceDue = computed(() => {
    const b = this.bill();
    return b ? b.amount - b.paidAmount : 0;
  });

  readonly paymentForm = new FormGroup<PaymentFormModel>({
    paymentDate: new FormControl(toLocalIsoDate(), { nonNullable: true, validators: [Validators.required] }),
    amount: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0.01)] }),
    method: new FormControl('Bank Transfer', { nonNullable: true, validators: [Validators.required] }),
    referenceNo: new FormControl('', { nonNullable: true }),
  });

  constructor() {
    effect(() => this.pageTitleService.setTitle(this.bill()?.billNo ?? null));
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.loadBill();
  }

  private loadBill(): void {
    this.loading.set(true);
    this.vendorService.getVendorBillById(this.vendorBillId).subscribe({
      next: (bill) => {
        this.bill.set(bill);
        this.resetPaymentForm();
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  private resetPaymentForm(): void {
    const balance = Math.max(0, Math.round(this.balanceDue() * 100) / 100);
    const amount = this.paymentForm.controls.amount;
    amount.setValidators([Validators.required, Validators.min(0.01), Validators.max(balance)]);
    this.paymentForm.reset({
      paymentDate: toLocalIsoDate(),
      amount: balance > 0 ? balance : null,
      method: 'Bank Transfer',
      referenceNo: '',
    });
  }

  recordPayment(): void {
    if (this.paymentForm.invalid) {
      this.paymentForm.markAllAsTouched();
      return;
    }

    const value = this.paymentForm.getRawValue();
    this.savingPayment.set(true);

    this.vendorService
      .createVendorPayment(this.vendorBillId, {
        paymentDate: value.paymentDate,
        amount: value.amount!,
        method: value.method,
        referenceNo: value.referenceNo || undefined,
      })
      .subscribe({
        next: () => {
          this.savingPayment.set(false);
          this.toast.success('Payment recorded');
          this.loadBill();
        },
        error: () => this.savingPayment.set(false),
      });
  }

  removePayment(payment: VendorPaymentModel): void {
    this.confirmDialog
      .confirm({
        title: 'Remove payment?',
        message: `Remove the payment of ₹${payment.amount.toLocaleString()} from ${payment.paymentDate}? The bill status will be re-evaluated.`,
        confirmLabel: 'Remove',
        destructive: true,
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.vendorService.deleteVendorPayment(payment.id).subscribe({
          next: () => {
            this.toast.success('Payment removed');
            this.loadBill();
          },
        });
      });
  }
}
