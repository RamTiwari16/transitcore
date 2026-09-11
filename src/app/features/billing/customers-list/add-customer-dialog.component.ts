import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { CreateCustomerRequest } from '../../../models/billing.models';

interface CustomerFormModel {
  code: FormControl<string>;
  name: FormControl<string>;
}

@Component({
  selector: 'app-add-customer-dialog',
  imports: [ReactiveFormsModule, MatDialogModule, MatButtonModule, MatFormFieldModule, MatInputModule],
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

  readonly form = new FormGroup<CustomerFormModel>({
    code: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(50)] }),
    name: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(200)] }),
  });

  submit(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const request: CreateCustomerRequest = this.form.getRawValue();
    this.dialogRef.close(request);
  }
}
