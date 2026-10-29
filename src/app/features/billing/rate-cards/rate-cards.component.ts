import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatSelectModule } from '@angular/material/select';
import { MatTooltipModule } from '@angular/material/tooltip';
import { BillingService } from '../../../services/billing.service';
import { LookupService } from '../../../services/lookup.service';
import { ConfirmDialogService } from '../../../core/services/confirm-dialog.service';
import { ToastService } from '../../../core/services/toast.service';
import { CustomerModel, RateCardModel } from '../../../models/billing.models';
import { CityModel } from '../../../models/lookup.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { InrPipe } from '../../../shared/pipes/inr.pipe';
import { toLocalIsoDate } from '../../../shared/util/date';

interface RateCardFormModel {
  customerId: FormControl<number | null>;
  originCityId: FormControl<number | null>;
  destinationCityId: FormControl<number | null>;
  basis: FormControl<string>;
  ratePerTrip: FormControl<number | null>;
  ratePerTon: FormControl<number | null>;
  ratePerKm: FormControl<number | null>;
  ratePerPackage: FormControl<number | null>;
  minimumChargeableWeightKg: FormControl<number | null>;
  loadingRatePerEvent: FormControl<number | null>;
  unloadingRatePerEvent: FormControl<number | null>;
  detentionFreeHours: FormControl<number | null>;
  detentionRatePerHour: FormControl<number | null>;
  haltingRatePerDay: FormControl<number | null>;
  effectiveFrom: FormControl<string>;
  effectiveTo: FormControl<string>;
}

export const RATE_CARD_BASES = ['PerTrip', 'PerTon', 'PerKm', 'PerPackage'] as const;

@Component({
  selector: 'app-rate-cards',
  imports: [
    ReactiveFormsModule,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule,
    MatSelectModule,
    MatTooltipModule,
    EmptyStateComponent,
    InrPipe,
    DatePipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './rate-cards.component.html',
  styleUrl: './rate-cards.component.scss',
})
export class RateCardsComponent {
  private readonly billingService = inject(BillingService);
  private readonly lookupService = inject(LookupService);
  private readonly confirmDialog = inject(ConfirmDialogService);
  private readonly toast = inject(ToastService);

  readonly customers = signal<CustomerModel[]>([]);
  readonly cities = signal<CityModel[]>([]);
  readonly rateCards = signal<RateCardModel[]>([]);
  readonly loading = signal(true);
  readonly saving = signal(false);

  readonly bases = RATE_CARD_BASES;

  readonly form = new FormGroup<RateCardFormModel>({
    customerId: new FormControl<number | null>(null),
    originCityId: new FormControl<number | null>(null),
    destinationCityId: new FormControl<number | null>(null),
    basis: new FormControl('PerKm', { nonNullable: true, validators: [Validators.required] }),
    ratePerTrip: new FormControl<number | null>(null),
    ratePerTon: new FormControl<number | null>(null),
    ratePerKm: new FormControl<number | null>(null),
    ratePerPackage: new FormControl<number | null>(null),
    minimumChargeableWeightKg: new FormControl<number | null>(null),
    loadingRatePerEvent: new FormControl<number | null>(null),
    unloadingRatePerEvent: new FormControl<number | null>(null),
    detentionFreeHours: new FormControl<number | null>(null),
    detentionRatePerHour: new FormControl<number | null>(null),
    haltingRatePerDay: new FormControl<number | null>(null),
    effectiveFrom: new FormControl(this.today(), { nonNullable: true, validators: [Validators.required] }),
    effectiveTo: new FormControl('', { nonNullable: true }),
  });

  // The rate field for the currently-selected basis is the only one
  // required - the other basis-specific rates stay optional/unused.
  private activeRateControl() {
    const basis = this.form.controls.basis.value;
    return basis === 'PerTrip'
      ? this.form.controls.ratePerTrip
      : basis === 'PerTon'
        ? this.form.controls.ratePerTon
        : basis === 'PerPackage'
          ? this.form.controls.ratePerPackage
          : this.form.controls.ratePerKm;
  }

  constructor() {
    this.billingService.getCustomers(true).subscribe((customers) => this.customers.set(customers));
    this.lookupService.getCities().subscribe((cities) => this.cities.set(cities));
    this.loadRateCards();
  }

  private today(): string {
    return toLocalIsoDate();
  }

  activeRateLabel(card: RateCardModel): string {
    switch (card.basis) {
      case 'PerTrip':
        return `₹${card.ratePerTrip ?? 0}/trip`;
      case 'PerTon':
        return `₹${card.ratePerTon ?? 0}/ton`;
      case 'PerPackage':
        return `₹${card.ratePerPackage ?? 0}/package`;
      default:
        return `₹${card.ratePerKm}/km`;
    }
  }

  private loadRateCards(): void {
    this.loading.set(true);
    this.billingService.getRateCards().subscribe({
      next: (rateCards) => {
        this.rateCards.set(rateCards);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }

  addRateCard(): void {
    this.form.markAllAsTouched();
    const activeRate = this.activeRateControl();

    if (this.form.invalid || activeRate.value === null || activeRate.value <= 0) {
      return;
    }

    const value = this.form.getRawValue();
    this.saving.set(true);

    this.billingService
      .createRateCard({
        customerId: value.customerId ?? undefined,
        originCityId: value.originCityId ?? undefined,
        destinationCityId: value.destinationCityId ?? undefined,
        ratePerKg: 0,
        ratePerKm: value.ratePerKm ?? 0,
        basis: value.basis,
        ratePerTrip: value.ratePerTrip ?? undefined,
        ratePerTon: value.ratePerTon ?? undefined,
        ratePerPackage: value.ratePerPackage ?? undefined,
        minimumChargeableWeightKg: value.minimumChargeableWeightKg ?? undefined,
        loadingRatePerEvent: value.loadingRatePerEvent ?? undefined,
        unloadingRatePerEvent: value.unloadingRatePerEvent ?? undefined,
        detentionFreeHours: value.detentionFreeHours ?? undefined,
        detentionRatePerHour: value.detentionRatePerHour ?? undefined,
        haltingRatePerDay: value.haltingRatePerDay ?? undefined,
        effectiveFrom: value.effectiveFrom,
        effectiveTo: value.effectiveTo || undefined,
      })
      .subscribe({
        next: () => {
          this.saving.set(false);
          this.form.reset({
            customerId: null,
            originCityId: null,
            destinationCityId: null,
            basis: 'PerKm',
            ratePerTrip: null,
            ratePerTon: null,
            ratePerKm: null,
            ratePerPackage: null,
            minimumChargeableWeightKg: null,
            loadingRatePerEvent: null,
            unloadingRatePerEvent: null,
            detentionFreeHours: null,
            detentionRatePerHour: null,
            haltingRatePerDay: null,
            effectiveFrom: this.today(),
            effectiveTo: '',
          });
          this.toast.success('Rate card added');
          this.loadRateCards();
        },
        error: () => this.saving.set(false),
      });
  }

  removeRateCard(rateCard: RateCardModel): void {
    this.confirmDialog
      .confirm({
        title: 'Remove rate card?',
        message: `Remove this ${rateCard.basis} rate card?`,
        confirmLabel: 'Remove',
        destructive: true,
      })
      .subscribe((confirmed) => {
        if (!confirmed) return;
        this.billingService.deleteRateCard(rateCard.id).subscribe({
          next: () => {
            this.toast.success('Rate card removed');
            this.loadRateCards();
          },
        });
      });
  }
}
