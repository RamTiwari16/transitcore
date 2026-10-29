import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { VendorService } from '../../../services/vendor.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';

interface VendorFormModel {
  code: FormControl<string>;
  name: FormControl<string>;
  contactName: FormControl<string>;
  contactPhone: FormControl<string>;
  contactEmail: FormControl<string>;
  address: FormControl<string>;
  bankAccountNo: FormControl<string>;
  bankIfscCode: FormControl<string>;
  panNo: FormControl<string>;
  gstinNo: FormControl<string>;
  isActive: FormControl<boolean>;
}

@Component({
  selector: 'app-vendor-form',
  imports: [RouterLink, ReactiveFormsModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatCheckboxModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './vendor-form.component.html',
  styleUrl: './vendor-form.component.scss',
})
export class VendorFormComponent implements CanComponentDeactivate {
  readonly saving = signal(false);
  readonly loading = signal(false);
  private submitted = false;

  private readonly vendorId = signal<number | null>(null);
  readonly isEditMode = computed(() => this.vendorId() !== null);

  // Code is the immutable natural key once created (matches Customer's
  // convention) - disabled, not omitted, in edit mode so it stays visible.
  readonly form = new FormGroup<VendorFormModel>({
    code: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(30)] }),
    name: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(200)] }),
    contactName: new FormControl('', { nonNullable: true }),
    contactPhone: new FormControl('', { nonNullable: true }),
    contactEmail: new FormControl('', { nonNullable: true, validators: [Validators.email] }),
    address: new FormControl('', { nonNullable: true }),
    bankAccountNo: new FormControl('', { nonNullable: true }),
    bankIfscCode: new FormControl('', { nonNullable: true }),
    panNo: new FormControl('', { nonNullable: true }),
    gstinNo: new FormControl('', { nonNullable: true }),
    isActive: new FormControl(true, { nonNullable: true }),
  });

  constructor(
    private vendorService: VendorService,
    private toast: ToastService,
    private router: Router,
    private route: ActivatedRoute,
  ) {
    const pageTitleService = inject(PageTitleService);
    effect(() => pageTitleService.setTitle(this.isEditMode() ? 'Edit Vendor' : 'Add Vendor'));
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));

    const idParam = this.route.snapshot.paramMap.get('id');
    if (idParam) {
      const id = Number(idParam);
      this.vendorId.set(id);
      this.loading.set(true);
      this.vendorService.getVendorById(id).subscribe({
        next: (vendor) => {
          this.form.patchValue({
            code: vendor.code,
            name: vendor.name,
            contactName: vendor.contactName ?? '',
            contactPhone: vendor.contactPhone ?? '',
            contactEmail: vendor.contactEmail ?? '',
            address: vendor.address ?? '',
            bankAccountNo: vendor.bankAccountNo ?? '',
            bankIfscCode: vendor.bankIfscCode ?? '',
            panNo: vendor.panNo ?? '',
            gstinNo: vendor.gstinNo ?? '',
            isActive: vendor.isActive,
          });
          this.form.controls.code.disable();
          this.loading.set(false);
        },
        error: () => this.loading.set(false),
      });
    }
  }

  hasUnsavedChanges(): boolean {
    return this.form.dirty && !this.submitted;
  }

  save(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const value = this.form.getRawValue();
    this.saving.set(true);

    const id = this.vendorId();
    const save$: Observable<unknown> = id
      ? this.vendorService.updateVendor({
          vendorId: id,
          name: value.name,
          contactName: value.contactName || undefined,
          contactPhone: value.contactPhone || undefined,
          contactEmail: value.contactEmail || undefined,
          address: value.address || undefined,
          bankAccountNo: value.bankAccountNo || undefined,
          bankIfscCode: value.bankIfscCode || undefined,
          panNo: value.panNo || undefined,
          gstinNo: value.gstinNo || undefined,
          isActive: value.isActive,
        })
      : this.vendorService.createVendor({
          code: value.code,
          name: value.name,
          contactName: value.contactName || undefined,
          contactPhone: value.contactPhone || undefined,
          contactEmail: value.contactEmail || undefined,
          address: value.address || undefined,
          bankAccountNo: value.bankAccountNo || undefined,
          bankIfscCode: value.bankIfscCode || undefined,
          panNo: value.panNo || undefined,
          gstinNo: value.gstinNo || undefined,
        });

    save$.subscribe({
      next: () => {
        this.submitted = true;
        this.toast.success(id ? 'Vendor updated successfully' : 'Vendor added successfully');
        this.router.navigate(['/vendors']);
      },
      error: () => this.saving.set(false),
    });
  }
}
