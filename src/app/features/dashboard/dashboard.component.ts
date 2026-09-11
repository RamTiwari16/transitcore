import { ChangeDetectionStrategy, Component, computed, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { forkJoin } from 'rxjs';
import { FleetService } from '../../services/fleet.service';
import { OpsService } from '../../services/ops.service';
import { BillingService } from '../../services/billing.service';
import { StatCardComponent } from '../../shared/components/stat-card/stat-card.component';
import { BarChartComponent, BarChartItem } from '../../shared/components/bar-chart/bar-chart.component';
import { DonutChartComponent, DonutChartItem } from '../../shared/components/donut-chart/donut-chart.component';
import { EmptyStateComponent } from '../../shared/components/empty-state/empty-state.component';
import { TripModel } from '../../models/ops.models';
import { InvoiceModel } from '../../models/billing.models';

function toIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

// Fixed colour per status so a given status always reads the same way
// across the trip and invoice donuts (and matches the semantic tone used
// elsewhere - success/warning/danger/info surfaces on stat cards etc).
const TRIP_STATUS_COLORS: Record<string, string> = {
  Scheduled: 'var(--tc-color-primary)',
  'In Transit': 'var(--tc-color-info)',
  Delayed: 'var(--tc-color-warning)',
  Completed: 'var(--tc-color-success)',
  Cancelled: 'var(--tc-color-danger)',
};

const INVOICE_STATUS_COLORS: Record<string, string> = {
  Draft: 'var(--tc-color-primary)',
  Sent: 'var(--tc-color-info)',
  'Partially Paid': 'var(--tc-color-warning)',
  Paid: 'var(--tc-color-success)',
  Overdue: 'var(--tc-color-danger)',
  Void: 'var(--tc-text-tertiary)',
};

function countByStatus(items: { statusName: string }[], colors: Record<string, string>): DonutChartItem[] {
  const counts = new Map<string, number>();
  for (const item of items) {
    counts.set(item.statusName, (counts.get(item.statusName) ?? 0) + 1);
  }
  return Array.from(counts.entries()).map(([label, value]) => ({
    label,
    value,
    color: colors[label] ?? 'var(--tc-text-tertiary)',
  }));
}

@Component({
  selector: 'app-dashboard',
  imports: [CommonModule, RouterLink, StatCardComponent, BarChartComponent, DonutChartComponent, EmptyStateComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss',
})
export class DashboardComponent {
  readonly loading = signal(true);

  private readonly trips = signal<TripModel[]>([]);
  private readonly invoices = signal<InvoiceModel[]>([]);
  private readonly utilisationData = signal<BarChartItem[]>([]);
  readonly totalInvoiced = signal(0);
  readonly totalOutstanding = signal(0);
  readonly vehiclesInMaintenance = signal(0);
  readonly overdueInvoiceCount = signal(0);

  readonly activeTrips = computed(() =>
    this.trips().filter((t) => t.statusName === 'In Transit' || t.statusName === 'Scheduled'),
  );

  readonly totalTrips = computed(() => this.trips().length);
  readonly utilisationChartData = this.utilisationData;

  readonly tripStatusBreakdown = computed(() => countByStatus(this.trips(), TRIP_STATUS_COLORS));
  readonly invoiceStatusBreakdown = computed(() => countByStatus(this.invoices(), INVOICE_STATUS_COLORS));

  constructor(
    private fleetService: FleetService,
    private opsService: OpsService,
    private billingService: BillingService,
  ) {
    this.loadDashboard();
  }

  private loadDashboard(): void {
    const today = new Date();
    const monthAgo = new Date();
    monthAgo.setDate(today.getDate() - 30);
    const weekAhead = new Date();
    weekAhead.setDate(today.getDate() + 7);

    const fromDate = toIsoDate(monthAgo);
    const toDate = toIsoDate(today);

    // pageSize: 1000 is a pragmatic stand-in for a real aggregate-count
    // endpoint - fine at this data volume, not meant to scale past it.
    forkJoin({
      utilisation: this.fleetService.getFleetUtilisation(fromDate, toDate),
      vehicles: this.fleetService.getVehicles(1, 1000),
      trips: this.opsService.getTrips(
        { fromDate: fromDate + 'T00:00:00', toDate: toIsoDate(weekAhead) + 'T23:59:59' },
        1,
        1000,
      ),
      invoiceSummary: this.billingService.getInvoiceSummary(fromDate, toDate),
      invoices: this.billingService.getInvoices({}),
    }).subscribe({
      next: ({ utilisation, vehicles, trips, invoiceSummary, invoices }) => {
        this.utilisationData.set(
          utilisation
            .slice(0, 8)
            .map((u) => ({ label: u.registrationNo, value: u.utilisationPercent })),
        );
        this.vehiclesInMaintenance.set(vehicles.items.filter((v) => v.statusName === 'In Maintenance').length);
        this.trips.set(trips.items);
        this.invoices.set(invoices);
        this.totalInvoiced.set(invoiceSummary.totalInvoiced);
        this.totalOutstanding.set(invoiceSummary.totalOutstanding);
        this.overdueInvoiceCount.set(invoices.filter((i) => i.statusName === 'Overdue').length);
        this.loading.set(false);
      },
      error: () => {
        this.loading.set(false);
      },
    });
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
  }

  formatDateTime(value: string): string {
    return new Date(value).toLocaleString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
  }
}
