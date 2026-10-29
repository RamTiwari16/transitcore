import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatSlideToggleModule } from '@angular/material/slide-toggle';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';

export interface LookupPanelRow {
  id: number;
  name: string;
  code?: string;
  parentId?: number;
  parentName?: string;
  isActive?: boolean;
}

export interface LookupPanelFormValue {
  id: number | null;
  name: string;
  code?: string;
  parentId?: number;
  isActive?: boolean;
}

// Reusable list+inline-form CRUD panel for the "simple" master-data lookups
// (Name-only, Code+Name, or Name+one-parent-FK - 7 of the 8 lookup.* admin
// tables share this exact shape; StatusCodes is the one-off with 4 fields
// and gets its own bespoke tab in MasterDataComponent instead of this).
@Component({
  selector: 'app-lookup-admin-panel',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatIconModule,
    MatTooltipModule,
    MatSlideToggleModule,
    EmptyStateComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './lookup-admin-panel.component.html',
  styleUrl: './lookup-admin-panel.component.scss',
})
export class LookupAdminPanelComponent {
  readonly rows = input.required<LookupPanelRow[]>();
  readonly loading = input(false);
  readonly saving = input(false);
  readonly entityLabel = input.required<string>();
  readonly hasCode = input(false);
  readonly codeLabel = input('Code');
  readonly codeMaxLength = input<number | null>(null);
  readonly parentLabel = input<string | null>(null);
  readonly parentOptions = input<{ id: number; name: string }[]>([]);
  // Only meaningful on edit - a brand-new row is always active, matching
  // every other lookup's CreateXRequest (none of them accept isActive).
  readonly hasActiveToggle = input(false);

  readonly saveRow = output<LookupPanelFormValue>();
  readonly deleteRow = output<LookupPanelRow>();

  readonly editingId = signal<number | null>(null);

  readonly form = new FormGroup({
    name: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
    code: new FormControl('', { nonNullable: true }),
    parentId: new FormControl<number | null>(null),
    isActive: new FormControl(true, { nonNullable: true }),
  });

  startEdit(row: LookupPanelRow): void {
    this.editingId.set(row.id);
    this.form.setValue({ name: row.name, code: row.code ?? '', parentId: row.parentId ?? null, isActive: row.isActive ?? true });
  }

  cancelEdit(): void {
    this.editingId.set(null);
    this.form.reset({ name: '', code: '', parentId: null, isActive: true });
  }

  submit(): void {
    if (this.parentLabel()) {
      this.form.controls.parentId.setValidators([Validators.required]);
      this.form.controls.parentId.updateValueAndValidity({ emitEvent: false });
    }

    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const value = this.form.getRawValue();
    this.saveRow.emit({
      id: this.editingId(),
      name: value.name,
      code: this.hasCode() ? value.code : undefined,
      parentId: this.parentLabel() ? (value.parentId ?? undefined) : undefined,
      isActive: this.hasActiveToggle() ? value.isActive : undefined,
    });
  }
}
