import { ChangeDetectionStrategy, Component, DestroyRef, computed, effect, inject, signal } from '@angular/core';
import { Observable } from 'rxjs';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { UserManagementService } from '../../../services/user-management.service';
import { LookupService } from '../../../services/lookup.service';
import { ToastService } from '../../../core/services/toast.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { RoleModel } from '../../../models/user-management.models';
import { BranchModel, DesignationModel, RegionModel, WorkingDesignationModel } from '../../../models/lookup.models';
import { CanComponentDeactivate } from '../../../core/guards/unsaved-changes.guard';

interface UserFormModel {
  email: FormControl<string>;
  password: FormControl<string>;
  displayName: FormControl<string>;
  phoneNo: FormControl<string>;
  empCode: FormControl<string>;
  designationId: FormControl<number | null>;
  workingDesignationId: FormControl<number | null>;
  regionId: FormControl<number | null>;
  punchLocation: FormControl<string>;
  shift: FormControl<string>;
  company: FormControl<string>;
  isActive: FormControl<boolean>;
  branchIds: FormControl<number[]>;
  roleIds: FormControl<number[]>;
}

@Component({
  selector: 'app-user-form',
  imports: [
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatCheckboxModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './user-form.component.html',
  styleUrl: './user-form.component.scss',
})
export class UserFormComponent implements CanComponentDeactivate {
  readonly roles = signal<RoleModel[]>([]);
  readonly branches = signal<BranchModel[]>([]);
  readonly designations = signal<DesignationModel[]>([]);
  readonly workingDesignations = signal<WorkingDesignationModel[]>([]);
  readonly regions = signal<RegionModel[]>([]);
  readonly saving = signal(false);
  readonly loading = signal(false);
  private submitted = false;

  private readonly userId = signal<number | null>(null);
  readonly isEditMode = computed(() => this.userId() !== null);

  readonly form = new FormGroup<UserFormModel>({
    email: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.email] }),
    password: new FormControl('', { nonNullable: true }),
    displayName: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(200)] }),
    phoneNo: new FormControl('', { nonNullable: true }),
    empCode: new FormControl('', { nonNullable: true }),
    designationId: new FormControl<number | null>(null),
    workingDesignationId: new FormControl<number | null>(null),
    regionId: new FormControl<number | null>(null),
    punchLocation: new FormControl('', { nonNullable: true }),
    shift: new FormControl('', { nonNullable: true }),
    company: new FormControl('', { nonNullable: true }),
    isActive: new FormControl(true, { nonNullable: true }),
    branchIds: new FormControl<number[]>([], { nonNullable: true }),
    roleIds: new FormControl<number[]>([], { nonNullable: true, validators: [Validators.required, Validators.minLength(1)] }),
  });

  constructor(
    private userManagementService: UserManagementService,
    private lookupService: LookupService,
    private toast: ToastService,
    private router: Router,
    private route: ActivatedRoute,
  ) {
    const pageTitleService = inject(PageTitleService);
    effect(() => pageTitleService.setTitle(this.isEditMode() ? 'Edit User' : 'Add User'));
    inject(DestroyRef).onDestroy(() => pageTitleService.setTitle(null));

    this.userManagementService.getRoles().subscribe((roles) => this.roles.set(roles));
    this.lookupService.getBranches().subscribe((branches) => this.branches.set(branches));
    this.lookupService.getDesignations().subscribe((designations) => this.designations.set(designations));
    this.lookupService.getWorkingDesignations().subscribe((wd) => this.workingDesignations.set(wd));
    this.lookupService.getRegions().subscribe((regions) => this.regions.set(regions));

    const idParam = this.route.snapshot.paramMap.get('id');
    if (idParam) {
      const id = Number(idParam);
      this.userId.set(id);
      this.form.controls.email.disable();
      this.form.controls.password.clearValidators();
      this.loading.set(true);

      this.userManagementService.getUserById(id).subscribe({
        next: (user) => {
          this.form.patchValue({
            email: user.email,
            displayName: user.displayName,
            phoneNo: user.phoneNo ?? '',
            empCode: user.empCode ?? '',
            designationId: user.designationId,
            workingDesignationId: user.workingDesignationId,
            regionId: user.regionId,
            punchLocation: user.punchLocation ?? '',
            shift: user.shift ?? '',
            company: user.company ?? '',
            isActive: user.isActive,
            branchIds: [...user.branchIds],
            roleIds: [...user.roleIds],
          });
          this.loading.set(false);
        },
        error: () => this.loading.set(false),
      });
    } else {
      this.form.controls.password.setValidators([Validators.required, Validators.minLength(6)]);
    }
  }

  hasUnsavedChanges(): boolean {
    return this.form.dirty && !this.submitted;
  }

  save(): void {
    this.form.markAllAsTouched();

    if (this.form.invalid) {
      return;
    }

    const value = this.form.getRawValue();
    this.saving.set(true);

    const id = this.userId();
    const save$: Observable<unknown> = id
      ? this.userManagementService.updateUser({
          userId: id,
          displayName: value.displayName,
          phoneNo: value.phoneNo || undefined,
          designationId: value.designationId ?? undefined,
          workingDesignationId: value.workingDesignationId ?? undefined,
          regionId: value.regionId ?? undefined,
          punchLocation: value.punchLocation || undefined,
          shift: value.shift || undefined,
          company: value.company || undefined,
          isActive: value.isActive,
          branchIds: value.branchIds,
          roleIds: value.roleIds,
        })
      : this.userManagementService.createUser({
          email: value.email,
          password: value.password,
          displayName: value.displayName,
          phoneNo: value.phoneNo || undefined,
          empCode: value.empCode || undefined,
          designationId: value.designationId ?? undefined,
          workingDesignationId: value.workingDesignationId ?? undefined,
          regionId: value.regionId ?? undefined,
          punchLocation: value.punchLocation || undefined,
          shift: value.shift || undefined,
          company: value.company || undefined,
          branchIds: value.branchIds,
          roleIds: value.roleIds,
        });

    save$.subscribe({
      next: () => {
        this.submitted = true;
        this.toast.success(id ? 'User updated successfully' : 'User added successfully');
        this.router.navigate(['/admin/users']);
      },
      // errorInterceptor already surfaces the failure as a toast - this
      // only needs to re-enable the form so the user can retry.
      error: () => this.saving.set(false),
    });
  }
}
