import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';

export interface ResetPasswordDialogData {
  userId: number;
  displayName: string;
}

interface ResetPasswordFormModel {
  newPassword: FormControl<string>;
}

@Component({
  selector: 'app-reset-password-dialog',
  imports: [ReactiveFormsModule, MatDialogModule, MatButtonModule, MatFormFieldModule, MatInputModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './reset-password-dialog.component.html',
  styles: `
    .reset-password-dialog__field {
      width: 100%;
      display: block;
    }
  `,
})
export class ResetPasswordDialogComponent {
  readonly dialogRef = inject(MatDialogRef<ResetPasswordDialogComponent>);
  readonly data = inject<ResetPasswordDialogData>(MAT_DIALOG_DATA);

  readonly form = new FormGroup<ResetPasswordFormModel>({
    newPassword: new FormControl('', {
      nonNullable: true,
      validators: [Validators.required, Validators.minLength(6)],
    }),
  });

  submit(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.dialogRef.close(this.form.getRawValue().newPassword);
  }
}
