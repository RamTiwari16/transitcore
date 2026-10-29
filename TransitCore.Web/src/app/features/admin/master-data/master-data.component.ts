import { ChangeDetectionStrategy, Component, computed, inject, signal, viewChild } from '@angular/core';
import { Observable } from 'rxjs';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatTabsModule } from '@angular/material/tabs';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { LookupService } from '../../../services/lookup.service';
import { LookupAdminService } from '../../../services/lookup-admin.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { ToastService } from '../../../core/services/toast.service';
import {
  BranchModel,
  CityModel,
  DesignationModel,
  RegionModel,
  StatusCodeModel,
  UnitOfMeasureModel,
  WorkingDesignationModel,
} from '../../../models/lookup.models';
import { CountryModel, RequiredComplianceDocumentTypeModel } from '../../../models/lookup-admin.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { LookupAdminPanelComponent, LookupPanelFormValue, LookupPanelRow } from '../lookup-admin-panel/lookup-admin-panel.component';

interface StatusCodeFormModel {
  category: FormControl<string>;
  code: FormControl<string>;
  name: FormControl<string>;
  sortOrder: FormControl<number | null>;
}

@Component({
  selector: 'app-master-data',
  imports: [
    ReactiveFormsModule,
    MatTabsModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatIconModule,
    MatTooltipModule,
    EmptyStateComponent,
    LookupAdminPanelComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './master-data.component.html',
  styleUrl: './master-data.component.scss',
})
export class MasterDataComponent {
  private readonly lookupService = inject(LookupService);
  private readonly lookupAdminService = inject(LookupAdminService);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly toast = inject(ToastService);

  private readonly regionsPanel = viewChild<LookupAdminPanelComponent>('regionsPanel');
  private readonly workingDesignationsPanel = viewChild<LookupAdminPanelComponent>('workingDesignationsPanel');
  private readonly designationsPanel = viewChild<LookupAdminPanelComponent>('designationsPanel');
  private readonly countriesPanel = viewChild<LookupAdminPanelComponent>('countriesPanel');
  private readonly unitsPanel = viewChild<LookupAdminPanelComponent>('unitsPanel');
  private readonly branchesPanel = viewChild<LookupAdminPanelComponent>('branchesPanel');
  private readonly citiesPanel = viewChild<LookupAdminPanelComponent>('citiesPanel');
  private readonly complianceDocTypesPanel = viewChild<LookupAdminPanelComponent>('complianceDocTypesPanel');

  readonly loadingRegions = signal(true);
  readonly loadingWorkingDesignations = signal(true);
  readonly loadingDesignations = signal(true);
  readonly loadingCountries = signal(true);
  readonly loadingUnits = signal(true);
  readonly loadingBranches = signal(true);
  readonly loadingCities = signal(true);
  readonly loadingStatusCodes = signal(true);
  readonly savingStatusCode = signal(false);
  readonly loadingComplianceDocTypes = signal(true);

  private readonly regions = signal<RegionModel[]>([]);
  private readonly workingDesignations = signal<WorkingDesignationModel[]>([]);
  private readonly designations = signal<DesignationModel[]>([]);
  private readonly countries = signal<CountryModel[]>([]);
  private readonly units = signal<UnitOfMeasureModel[]>([]);
  private readonly branches = signal<BranchModel[]>([]);
  private readonly cities = signal<CityModel[]>([]);
  readonly statusCodes = signal<StatusCodeModel[]>([]);
  private readonly complianceDocTypes = signal<RequiredComplianceDocumentTypeModel[]>([]);

  readonly regionRows = computed<LookupPanelRow[]>(() => this.regions().map((r) => ({ id: r.id, name: r.name })));
  readonly workingDesignationRows = computed<LookupPanelRow[]>(() =>
    this.workingDesignations().map((wd) => ({ id: wd.id, name: wd.name })),
  );
  readonly designationRows = computed<LookupPanelRow[]>(() =>
    this.designations().map((d) => ({ id: d.id, name: d.name, code: d.code })),
  );
  readonly countryRows = computed<LookupPanelRow[]>(() => this.countries().map((c) => ({ id: c.id, name: c.name, code: c.code })));
  readonly unitRows = computed<LookupPanelRow[]>(() => this.units().map((u) => ({ id: u.id, name: u.name, code: u.code })));
  readonly branchRows = computed<LookupPanelRow[]>(() =>
    this.branches().map((b) => ({ id: b.id, name: b.name, code: b.code, parentId: b.regionId, parentName: b.regionName })),
  );
  readonly cityRows = computed<LookupPanelRow[]>(() =>
    this.cities().map((c) => ({ id: c.id, name: c.name, parentId: c.countryId, parentName: c.countryName })),
  );
  readonly complianceDocTypeRows = computed<LookupPanelRow[]>(() =>
    this.complianceDocTypes().map((d) => ({ id: d.id, name: d.documentType, isActive: d.isActive })),
  );

  readonly regionOptions = computed(() => this.regions().map((r) => ({ id: r.id, name: r.name })));
  readonly countryOptions = computed(() => this.countries().map((c) => ({ id: c.id, name: c.name })));

  readonly editingStatusCodeId = signal<number | null>(null);

  readonly statusCodeForm = new FormGroup<StatusCodeFormModel>({
    category: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(50)] }),
    code: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(50)] }),
    name: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.maxLength(150)] }),
    sortOrder: new FormControl<number | null>(0, { validators: [Validators.required] }),
  });

  constructor() {
    this.loadRegions();
    this.loadWorkingDesignations();
    this.loadDesignations();
    this.loadCountries();
    this.loadUnits();
    this.loadBranches();
    this.loadCities();
    this.loadStatusCodes();
    this.loadComplianceDocTypes();
  }

  private loadComplianceDocTypes(): void {
    this.loadingComplianceDocTypes.set(true);
    this.lookupAdminService.getRequiredComplianceDocumentTypes().subscribe((data) => {
      this.complianceDocTypes.set(data);
      this.loadingComplianceDocTypes.set(false);
    });
  }

  private loadRegions(): void {
    this.loadingRegions.set(true);
    this.lookupService.getRegions().subscribe((data) => {
      this.regions.set(data);
      this.loadingRegions.set(false);
    });
  }

  private loadWorkingDesignations(): void {
    this.loadingWorkingDesignations.set(true);
    this.lookupService.getWorkingDesignations().subscribe((data) => {
      this.workingDesignations.set(data);
      this.loadingWorkingDesignations.set(false);
    });
  }

  private loadDesignations(): void {
    this.loadingDesignations.set(true);
    this.lookupService.getDesignations().subscribe((data) => {
      this.designations.set(data);
      this.loadingDesignations.set(false);
    });
  }

  private loadCountries(): void {
    this.loadingCountries.set(true);
    this.lookupAdminService.getCountries().subscribe((data) => {
      this.countries.set(data);
      this.loadingCountries.set(false);
    });
  }

  private loadUnits(): void {
    this.loadingUnits.set(true);
    this.lookupService.getUnitsOfMeasure().subscribe((data) => {
      this.units.set(data);
      this.loadingUnits.set(false);
    });
  }

  private loadBranches(): void {
    this.loadingBranches.set(true);
    this.lookupService.getBranches().subscribe((data) => {
      this.branches.set(data);
      this.loadingBranches.set(false);
    });
  }

  private loadCities(): void {
    this.loadingCities.set(true);
    this.lookupService.getCities().subscribe((data) => {
      this.cities.set(data);
      this.loadingCities.set(false);
    });
  }

  private loadStatusCodes(): void {
    this.loadingStatusCodes.set(true);
    this.lookupAdminService.getAllStatusCodes().subscribe((data) => {
      this.statusCodes.set(data);
      this.loadingStatusCodes.set(false);
    });
  }

  // ---- Regions ----
  saveRegion(value: LookupPanelFormValue): void {
    const save$: Observable<unknown> = value.id
      ? this.lookupAdminService.updateRegion({ id: value.id, name: value.name })
      : this.lookupAdminService.createRegion({ name: value.name });

    save$.subscribe(() => {
      this.toast.success(value.id ? 'Region updated' : 'Region added');
      this.regionsPanel()?.cancelEdit();
      this.loadRegions();
    });
  }

  deleteRegion(row: LookupPanelRow): void {
    this.confirmDialog
      .confirm({ title: 'Remove region?', message: `Remove "${row.name}"?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.lookupAdminService.deleteRegion(row.id).subscribe(() => {
          this.toast.success('Region removed');
          this.loadRegions();
        });
      });
  }

  // ---- Required compliance document types ----
  saveComplianceDocType(value: LookupPanelFormValue): void {
    const save$: Observable<unknown> = value.id
      ? this.lookupAdminService.updateRequiredComplianceDocumentType({
          id: value.id,
          documentType: value.name,
          isActive: value.isActive ?? true,
        })
      : this.lookupAdminService.createRequiredComplianceDocumentType({ documentType: value.name });

    save$.subscribe(() => {
      this.toast.success(value.id ? 'Document type updated' : 'Document type added');
      this.complianceDocTypesPanel()?.cancelEdit();
      this.loadComplianceDocTypes();
    });
  }

  deleteComplianceDocType(row: LookupPanelRow): void {
    this.confirmDialog
      .confirm({ title: 'Remove document type?', message: `Remove "${row.name}"?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.lookupAdminService.deleteRequiredComplianceDocumentType(row.id).subscribe(() => {
          this.toast.success('Document type removed');
          this.loadComplianceDocTypes();
        });
      });
  }

  // ---- Working designations ----
  saveWorkingDesignation(value: LookupPanelFormValue): void {
    const save$: Observable<unknown> = value.id
      ? this.lookupAdminService.updateWorkingDesignation({ id: value.id, name: value.name })
      : this.lookupAdminService.createWorkingDesignation({ name: value.name });

    save$.subscribe(() => {
      this.toast.success(value.id ? 'Working designation updated' : 'Working designation added');
      this.workingDesignationsPanel()?.cancelEdit();
      this.loadWorkingDesignations();
    });
  }

  deleteWorkingDesignation(row: LookupPanelRow): void {
    this.confirmDialog
      .confirm({ title: 'Remove working designation?', message: `Remove "${row.name}"?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.lookupAdminService.deleteWorkingDesignation(row.id).subscribe(() => {
          this.toast.success('Working designation removed');
          this.loadWorkingDesignations();
        });
      });
  }

  // ---- Designations ----
  saveDesignation(value: LookupPanelFormValue): void {
    const save$: Observable<unknown> = value.id
      ? this.lookupAdminService.updateDesignation({ id: value.id, name: value.name, code: value.code ?? '' })
      : this.lookupAdminService.createDesignation({ name: value.name, code: value.code ?? '' });

    save$.subscribe(() => {
      this.toast.success(value.id ? 'Designation updated' : 'Designation added');
      this.designationsPanel()?.cancelEdit();
      this.loadDesignations();
    });
  }

  deleteDesignation(row: LookupPanelRow): void {
    this.confirmDialog
      .confirm({ title: 'Remove designation?', message: `Remove "${row.name}"?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.lookupAdminService.deleteDesignation(row.id).subscribe(() => {
          this.toast.success('Designation removed');
          this.loadDesignations();
        });
      });
  }

  // ---- Countries ----
  saveCountry(value: LookupPanelFormValue): void {
    const save$: Observable<unknown> = value.id
      ? this.lookupAdminService.updateCountry({ id: value.id, name: value.name, code: value.code ?? '' })
      : this.lookupAdminService.createCountry({ name: value.name, code: value.code ?? '' });

    save$.subscribe(() => {
      this.toast.success(value.id ? 'Country updated' : 'Country added');
      this.countriesPanel()?.cancelEdit();
      this.loadCountries();
    });
  }

  deleteCountry(row: LookupPanelRow): void {
    this.confirmDialog
      .confirm({ title: 'Remove country?', message: `Remove "${row.name}"?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.lookupAdminService.deleteCountry(row.id).subscribe(() => {
          this.toast.success('Country removed');
          this.loadCountries();
        });
      });
  }

  // ---- Units of measure ----
  saveUnit(value: LookupPanelFormValue): void {
    const save$: Observable<unknown> = value.id
      ? this.lookupAdminService.updateUnitOfMeasure({ id: value.id, name: value.name, code: value.code ?? '' })
      : this.lookupAdminService.createUnitOfMeasure({ name: value.name, code: value.code ?? '' });

    save$.subscribe(() => {
      this.toast.success(value.id ? 'Unit of measure updated' : 'Unit of measure added');
      this.unitsPanel()?.cancelEdit();
      this.loadUnits();
    });
  }

  deleteUnit(row: LookupPanelRow): void {
    this.confirmDialog
      .confirm({ title: 'Remove unit of measure?', message: `Remove "${row.name}"?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.lookupAdminService.deleteUnitOfMeasure(row.id).subscribe(() => {
          this.toast.success('Unit of measure removed');
          this.loadUnits();
        });
      });
  }

  // ---- Branches ----
  saveBranch(value: LookupPanelFormValue): void {
    const save$: Observable<unknown> = value.id
      ? this.lookupAdminService.updateBranch({ id: value.id, name: value.name, code: value.code ?? '', regionId: value.parentId! })
      : this.lookupAdminService.createBranch({ name: value.name, code: value.code ?? '', regionId: value.parentId! });

    save$.subscribe(() => {
      this.toast.success(value.id ? 'Branch updated' : 'Branch added');
      this.branchesPanel()?.cancelEdit();
      this.loadBranches();
    });
  }

  deleteBranch(row: LookupPanelRow): void {
    this.confirmDialog
      .confirm({ title: 'Remove branch?', message: `Remove "${row.name}"?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.lookupAdminService.deleteBranch(row.id).subscribe(() => {
          this.toast.success('Branch removed');
          this.loadBranches();
        });
      });
  }

  // ---- Cities ----
  saveCity(value: LookupPanelFormValue): void {
    const save$: Observable<unknown> = value.id
      ? this.lookupAdminService.updateCity({ id: value.id, name: value.name, countryId: value.parentId! })
      : this.lookupAdminService.createCity({ name: value.name, countryId: value.parentId! });

    save$.subscribe(() => {
      this.toast.success(value.id ? 'City updated' : 'City added');
      this.citiesPanel()?.cancelEdit();
      this.loadCities();
    });
  }

  deleteCity(row: LookupPanelRow): void {
    this.confirmDialog
      .confirm({ title: 'Remove city?', message: `Remove "${row.name}"?`, confirmLabel: 'Remove', destructive: true })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.lookupAdminService.deleteCity(row.id).subscribe(() => {
          this.toast.success('City removed');
          this.loadCities();
        });
      });
  }

  // ---- Status codes (bespoke: Category + Code + Name + SortOrder, no parent FK) ----
  editStatusCode(row: StatusCodeModel): void {
    this.editingStatusCodeId.set(row.id);
    this.statusCodeForm.setValue({ category: row.category, code: row.code, name: row.name, sortOrder: row.sortOrder });
  }

  cancelStatusCodeEdit(): void {
    this.editingStatusCodeId.set(null);
    this.statusCodeForm.reset({ category: '', code: '', name: '', sortOrder: 0 });
  }

  saveStatusCode(): void {
    if (this.statusCodeForm.invalid) {
      this.statusCodeForm.markAllAsTouched();
      return;
    }

    const value = this.statusCodeForm.getRawValue();
    const editingId = this.editingStatusCodeId();
    this.savingStatusCode.set(true);

    const save$: Observable<unknown> = editingId
      ? this.lookupAdminService.updateStatusCode({
          id: editingId,
          category: value.category,
          code: value.code,
          name: value.name,
          sortOrder: value.sortOrder!,
        })
      : this.lookupAdminService.createStatusCode({
          category: value.category,
          code: value.code,
          name: value.name,
          sortOrder: value.sortOrder!,
        });

    save$.subscribe({
      next: () => {
        this.savingStatusCode.set(false);
        this.toast.success(editingId ? 'Status code updated' : 'Status code added');
        this.cancelStatusCodeEdit();
        this.loadStatusCodes();
      },
      error: () => this.savingStatusCode.set(false),
    });
  }

  removeStatusCode(row: StatusCodeModel): void {
    this.confirmDialog
      .confirm({
        title: 'Remove status code?',
        message: `Remove "${row.category} / ${row.code}"? Records already using it will keep the reference.`,
        confirmLabel: 'Remove',
        destructive: true,
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.lookupAdminService.deleteStatusCode(row.id).subscribe(() => {
          this.toast.success('Status code removed');
          this.loadStatusCodes();
        });
      });
  }
}
