import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatTabsModule } from '@angular/material/tabs';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatTooltipModule } from '@angular/material/tooltip';
import { BillingService } from '../../../services/billing.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { InvoiceDetailModel, PaymentModel } from '../../../models/billing.models';
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
  selector: 'app-invoice-detail',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatTabsModule,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatProgressSpinnerModule,
    MatTooltipModule,
    EmptyStateComponent,
    InrPipe,
    DatePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './invoice-detail.component.html',
  styleUrl: './invoice-detail.component.scss',
})
export class InvoiceDetailComponent {
  private readonly billingService = inject(BillingService);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly toast = inject(ToastService);
  private readonly route = inject(ActivatedRoute);
  private readonly pageTitleService = inject(PageTitleService);
  private readonly invoiceId = Number(this.route.snapshot.paramMap.get('id'));

  readonly paymentMethods = PAYMENT_METHODS;

  readonly invoice = signal<InvoiceDetailModel | null>(null);
  readonly loading = signal(true);
  readonly downloadingPdf = signal(false);
  readonly savingPayment = signal(false);

  readonly balanceDue = computed(() => {
    const inv = this.invoice();
    return inv ? inv.totalAmount - inv.paidAmount : 0;
  });

  readonly paymentForm = new FormGroup<PaymentFormModel>({
    paymentDate: new FormControl(this.today(), { nonNullable: true, validators: [Validators.required] }),
    amount: new FormControl<number | null>(null, { validators: [Validators.required, Validators.min(0.01)] }),
    method: new FormControl('Bank Transfer', { nonNullable: true, validators: [Validators.required] }),
    referenceNo: new FormControl('', { nonNullable: true }),
  });

  constructor() {
    effect(() => this.pageTitleService.setTitle(this.invoice()?.invoiceNo ?? null));
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.loadInvoice();
  }

  private today(): string {
    return toLocalIsoDate();
  }

  private loadInvoice(): void {
    this.loading.set(true);
    this.billingService.getInvoiceById(this.invoiceId).subscribe({
      next: (invoice) => {
        this.invoice.set(invoice);
        this.resetPaymentForm();
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  downloadPdf(): void {
    const inv = this.invoice();
    if (!inv || this.downloadingPdf()) return;

    this.downloadingPdf.set(true);
    this.billingService.getInvoicePdf(inv.id).subscribe({
      next: (blob) => {
        this.downloadingPdf.set(false);
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${inv.invoiceNo}.pdf`;
        link.click();
        URL.revokeObjectURL(url);
      },
      error: () => this.downloadingPdf.set(false),
    });
  }

  recordPayment(): void {
    if (this.paymentForm.invalid) {
      this.paymentForm.markAllAsTouched();
      return;
    }

    const value = this.paymentForm.getRawValue();
    this.savingPayment.set(true);

    this.billingService
      .createPayment(this.invoiceId, {
        paymentDate: value.paymentDate,
        amount: value.amount!,
        method: value.method,
        referenceNo: value.referenceNo || undefined,
      })
      .subscribe({
        next: () => {
          this.savingPayment.set(false);
          this.toast.success('Payment recorded');
          this.loadInvoice();
        },
        error: () => this.savingPayment.set(false),
      });
  }

  private resetPaymentForm(): void {
    const balance = Math.max(0, Math.round(this.balanceDue() * 100) / 100);
    const amount = this.paymentForm.controls.amount;
    amount.setValidators([Validators.required, Validators.min(0.01), Validators.max(balance)]);
    this.paymentForm.reset({
      paymentDate: this.today(),
      amount: balance > 0 ? balance : null,
      method: 'Bank Transfer',
      referenceNo: '',
    });
  }

  removePayment(payment: PaymentModel): void {
    this.confirmDialog
      .confirm({
        title: 'Remove payment?',
        message: `Remove the payment of ₹${payment.amount.toLocaleString()} from ${payment.paymentDate}? The invoice status will be re-evaluated.`,
        confirmLabel: 'Remove',
        destructive: true,
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.billingService.deletePayment(payment.id).subscribe({
          next: () => {
            this.toast.success('Payment removed');
            this.loadInvoice();
          },
        });
      });
  }
}
