import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { CreateCustomerRequest, CustomerModel, UpdateCustomerRequest } from '../../../models/billing.models';

export interface AddCustomerDialogData {
  customer: CustomerModel;
}

export type AddCustomerDialogResult =
  | { mode: 'create'; request: CreateCustomerRequest }
  | { mode: 'edit'; request: UpdateCustomerRequest };

interface CustomerFormModel {
  code: FormControl<string>;
  name: FormControl<string>;
  isActive: FormControl<boolean>;
  creditLimit: FormControl<number | null>;
}

@Component({
  selector: 'app-add-customer-dialog',
  imports: [
    ReactiveFormsModule,
    MatDialogModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatCheckboxModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './add-customer-dialog.component.html',
  styles: `
    .add-customer-dialog__field {
      width: 100%;
      display: block;
    }
  `,
})
export class AddCustomerDialogComponent {
  readonly dialogRef = inject(MatDialogRef<AddCustomerDialogComponent>);
  private readonly data = inject<AddCustomerDialogData | null>(MAT_DIALOG_DATA, { optional: true });

  readonly isEditMode = this.data !== null;

  readonly form = new FormGroup<CustomerFormModel>({
    code: new FormControl(this.data?.customer.code ?? '', {
      nonNullable: true,
      validators: [Validators.required, Validators.maxLength(50)],
    }),
    name: new FormControl(this.data?.customer.name ?? '', {
      nonNullable: true,
      validators: [Validators.required, Validators.maxLength(200)],
    }),
    isActive: new FormControl(this.data?.customer.isActive ?? true, { nonNullable: true }),
    creditLimit: new FormControl<number | null>(this.data?.customer.creditLimit ?? null, { validators: [Validators.min(0)] }),
  });

  constructor() {
    // Code is the immutable natural key once a customer exists - see
    // usp_UpdateCustomer's comment - so it's locked rather than silently
    // ignored if the user edits it.
    if (this.isEditMode) {
      this.form.controls.code.disable();
    }
  }

  submit(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const value = this.form.getRawValue();

    if (this.isEditMode) {
      const result: AddCustomerDialogResult = {
        mode: 'edit',
        request: {
          customerId: this.data!.customer.id,
          name: value.name,
          isActive: value.isActive,
          creditLimit: value.creditLimit ?? undefined,
        },
      };
      this.dialogRef.close(result);
    } else {
      const result: AddCustomerDialogResult = {
        mode: 'create',
        request: { code: value.code, name: value.name, creditLimit: value.creditLimit ?? undefined },
      };
      this.dialogRef.close(result);
    }
  }
}
