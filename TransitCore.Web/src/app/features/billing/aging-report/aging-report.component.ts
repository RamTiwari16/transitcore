import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { BillingService } from '../../../services/billing.service';
import { AgingReportLineModel } from '../../../models/billing.models';
import { EmptyStateComponent } from '../../../shared/components/empty-state/empty-state.component';
import { PageTitleService } from '../../../core/services/page-title.service';
import { InrPipe } from '../../../shared/pipes/inr.pipe';
import { toLocalIsoDate } from '../../../shared/util/date';

interface AgingBucket {
  label: string;
  total: number;
}

@Component({
  selector: 'app-aging-report',
  imports: [
    DatePipe,
    RouterLink,
    FormsModule,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule,
    MatProgressSpinnerModule,
    EmptyStateComponent,
    InrPipe,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './aging-report.component.html',
  styleUrl: './aging-report.component.scss',
})
export class AgingReportComponent {
  private readonly billingService = inject(BillingService);
  private readonly pageTitleService = inject(PageTitleService);

  readonly asOfDate = signal(this.today());
  readonly lines = signal<AgingReportLineModel[]>([]);
  readonly loading = signal(true);

  readonly totalOutstanding = computed(() => this.lines().reduce((sum, l) => sum + l.outstandingAmount, 0));

  readonly buckets = computed<AgingBucket[]>(() => {
    const lines = this.lines();
    return [
      { label: 'Current', total: sumWhere(lines, (l) => l.daysOverdue <= 0) },
      { label: '1-30 days', total: sumWhere(lines, (l) => l.daysOverdue >= 1 && l.daysOverdue <= 30) },
      { label: '31-60 days', total: sumWhere(lines, (l) => l.daysOverdue >= 31 && l.daysOverdue <= 60) },
      { label: '61-90 days', total: sumWhere(lines, (l) => l.daysOverdue >= 61 && l.daysOverdue <= 90) },
      { label: '90+ days', total: sumWhere(lines, (l) => l.daysOverdue > 90) },
    ];
  });

  constructor() {
    this.pageTitleService.setTitle('Invoice Aging Report');
    inject(DestroyRef).onDestroy(() => this.pageTitleService.setTitle(null));

    this.load();
  }

  private today(): string {
    return toLocalIsoDate();
  }

  load(): void {
    this.loading.set(true);
    this.billingService.getAgingReport(this.asOfDate()).subscribe({
      next: (lines) => {
        this.lines.set(lines);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });
  }
}

function sumWhere(lines: AgingReportLineModel[], predicate: (l: AgingReportLineModel) => boolean): number {
  return lines.filter(predicate).reduce((sum, l) => sum + l.outstandingAmount, 0);
}
