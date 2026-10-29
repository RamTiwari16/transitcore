import { ChangeDetectionStrategy, Component, DestroyRef, effect, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { MatTabsModule } from '@angular/material/tabs';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { VendorService } from '../../../services/vendor.service';
import { PageTitleService } from '../../../core/services/page-title.service';
import { VendorBillModel, VendorModel, VendorOutstandingBalanceModel } from '../../../models/vendor.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { InrPipe } from '../../../shared/pipes/inr.pipe';

@Component({
  selector: 'app-vendor-detail',
  imports: [RouterLink, MatTabsModule, MatButtonModule, MatIconModule, EmptyStateComponent, InrPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './vendor-detail.component.html',
  styleUrl: './vendor-detail.component.scss',
})
export class VendorDetailComponent {
  private readonly vendorService = inject(VendorService);
  private readonly route = inject(ActivatedRoute);
  private readonly pageTitleService = inject(PageTitleService);
  private readonly vendorId = Number(this.route.snapshot.paramMap.get('id'));

  readonly vendor = signal<VendorModel | null>(null);
  readonly loading = signal(true);
  readonly outstandingBalance = signal<VendorOutstandingBalanceModel | null>(null);
  readonly bills = signal<VendorBillModel[]>([]);

  constructor() {
    effect(() => this.pageTitleService.setTitle(this.vendor()?.name ?? null));
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.vendorService.getVendorById(this.vendorId).subscribe({
      next: (vendor) => {
        this.vendor.set(vendor);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });

    this.vendorService.getVendorOutstandingBalance(this.vendorId).subscribe((b) => this.outstandingBalance.set(b));
    this.vendorService.getVendorBills(this.vendorId).subscribe((bills) => this.bills.set(bills));
  }
}
