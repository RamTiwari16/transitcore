import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { FormArray, FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { BillingService } from '../../../services/billing.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { CustomerModel } from '../../../models/billing.models';
import { StatusCodeModel } from '../../../models/lookup.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';
import { toLocalIsoDate } from '../../../shared/util/date';

interface InvoiceLineFormModel {
  description: FormControl<string>;
  quantity: FormControl<number | null>;
  unitPrice: FormControl<number | null>;
}

interface InvoiceFormModel {
  invoiceNo: FormControl<string>;
  customerId: FormControl<number | null>;
  invoiceDate: FormControl<string>;
  dueDate: FormControl<string>;
  discountAmount: FormControl<number | null>;
  taxAmount: FormControl<number | null>;
  statusId: FormControl<number | null>;
}

@Component({
  selector: 'app-invoice-form',
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
  templateUrl: './invoice-form.component.html',
  styleUrl: './invoice-form.component.scss',
})
export class InvoiceFormComponent implements CanComponentDeactivate {
  readonly customers = signal<CustomerModel[]>([]);
  readonly statusOptions = signal<StatusCodeModel[]>([]);
  readonly saving = signal(false);
  private submitted = false;

  readonly form = new FormGroup<InvoiceFormModel>({
    invoiceNo: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(30)] }),
    customerId: new FormControl<number | null>(null, { validators: [Validators.required] }),
    invoiceDate: new FormControl(this.today(), { nonNullable: true, validators: [Validators.required] }),
    dueDate: new FormControl(this.today(), { nonNullable: true, validators: [Validators.required] }),
    discountAmount: new FormControl<number | null>(0, { validators: [Validators.min(0)] }),
    taxAmount: new FormControl<number | null>(0, { validators: [Validators.min(0)] }),
    statusId: new FormControl<number | null>(null, { validators: [Validators.required] }),
  });

  readonly lines = new FormArray<FormGroup<InvoiceLineFormModel>>([]);

  constructor(
    private billingService: BillingService,
    private lookupService: LookupService,
    private toast: ToastService,
    private router: Router,
  ) {
    const pageTitleService = inject(PageTitleService);
    pageTitleService.setTitle('Add Invoice');
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));

    this.billingService.getCustomers(true).subscribe({
      next: (customers) => this.customers.set(customers),
    });
    this.lookupService.getStatusCodes('Invoice').subscribe({
      next: (statuses) => this.statusOptions.set(statuses),
    });

    this.addLine();
  }

  private today(): string {
    return toLocalIsoDate();
  }

  addLine(): void {
    this.lines.push(
      new FormGroup<InvoiceLineFormModel>({
        description: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
        quantity: new FormControl<number | null>(1, { validators: [Validators.required, Validators.min(0.01)] }),
        unitPrice: new FormControl<number | null>(0, { validators: [Validators.required, Validators.min(0)] }),
      }),
    );
  }

  removeLine(index: number): void {
    if (this.lines.length > 1) {
      this.lines.removeAt(index);
    }
  }

  hasUnsavedChanges(): boolean {
    return (this.form.dirty || this.lines.dirty) && !this.submitted;
  }

  save(): void {
    this.form.markAllAsTouched();
    this.lines.markAllAsTouched();

    if (this.form.invalid || this.lines.invalid) {
      return;
    }

    const value = this.form.getRawValue();
    this.saving.set(true);

    this.billingService
      .createInvoice({
        invoiceNo: value.invoiceNo,
        customerId: value.customerId!,
        invoiceDate: value.invoiceDate,
        dueDate: value.dueDate,
        discountAmount: value.discountAmount ?? 0,
        taxAmount: value.taxAmount ?? 0,
        statusId: value.statusId!,
        lines: this.lines.controls.map((group) => {
          const line = group.getRawValue();
          return {
            description: line.description,
            quantity: line.quantity!,
            unitPrice: line.unitPrice!,
          };
        }),
      })
      .subscribe({
        next: () => {
          this.submitted = true;
          this.toast.success('Invoice created successfully');
          this.router.navigate(['/billing/invoices']);
        },
        // errorInterceptor already surfaces the failure as a toast - this
        // only needs to re-enable the form so the user can retry.
        error: () => this.saving.set(false),
      });
  }
}
