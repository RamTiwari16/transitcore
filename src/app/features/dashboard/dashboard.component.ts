import { ChangeDetectionStrategy, Component, ElementRef, computed, effect, inject, signal, viewChild } from '@angular/core';
import { RouterLink } from '@angular/router';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { Chart, ChartConfiguration } from 'chart.js/auto';
import { FleetService } from '../../services/fleet.service';
import { OpsService } from '../../services/ops.service';
import { BillingService } from '../../services/billing.service';
import { ReportsService } from '../../services/reports.service';
import { AuthService } from '../../services/auth-service';
import { StatCardComponent } from '../../shared/components/stat-card/stat-card.component';
import { EmptyStateComponent } from '../../shared/components/empty-state/empty-state.component';
import { TripModel } from '../../models/ops.models';
import { CustomerModel, InvoiceModel } from '../../models/billing.models';
import {
  DriverSettlementSummaryModel,
  FleetUtilisationTrendModel,
  RevenueByPeriodModel,
  ShipmentVolumeTrendModel,
} from '../../models/reports.models';

function toIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

interface TopCustomerRow {
  customerId: number;
  name: string;
  invoiceCount: number;
  totalInvoiced: number;
  isActive: boolean;
}

function topCustomersByRevenue(invoices: InvoiceModel[], customers: CustomerModel[], limit: number): TopCustomerRow[] {
  const byCustomer = new Map<number, { totalInvoiced: number; invoiceCount: number }>();
  for (const invoice of invoices) {
    const entry = byCustomer.get(invoice.customerId) ?? { totalInvoiced: 0, invoiceCount: 0 };
    entry.totalInvoiced += invoice.totalAmount;
    entry.invoiceCount += 1;
    byCustomer.set(invoice.customerId, entry);
  }
  const customerById = new Map(customers.map((c) => [c.id, c]));

  return Array.from(byCustomer.entries())
    .map(([customerId, agg]) => ({
      customerId,
      name: customerById.get(customerId)?.name ?? `Customer #${customerId}`,
      isActive: customerById.get(customerId)?.isActive ?? true,
      ...agg,
    }))
    .sort((a, b) => b.totalInvoiced - a.totalInvoiced)
    .slice(0, limit);
}

// Collapses this app's 6-state invoice status onto the 3-bucket paid /
// partially-paid / unpaid split, matching how the reference dashboard's
// invoice breakdown reads at a glance.
function invoiceStatusBuckets(invoices: InvoiceModel[]): { paid: number; partial: number; unpaid: number } {
  let paid = 0;
  let partial = 0;
  let unpaid = 0;
  for (const invoice of invoices) {
    if (invoice.statusName === 'Paid') paid++;
    else if (invoice.statusName === 'Partially Paid') partial++;
    else unpaid++;
  }
  return { paid, partial, unpaid };
}

function cssVar(name: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

// Shared shape for every "monthly trend" chart card (revenue, shipment
// volume, fleet utilisation) and the two top-N bar cards (driver expenses,
// top routes): a bar per period/entity, the most recent/largest one
// highlighted in the brand color, the rest in a muted neutral, plus an
// overlaid trend line - mirrors the reference dashboard's chart.js config.
function buildTrendBarConfig(labels: string[], values: number[], valueSuffix: string): ChartConfiguration<'bar' | 'line'> {
  const accent = cssVar('--tc-color-primary');
  const muted = cssVar('--tc-surface-sunken');
  const grid = cssVar('--tc-divider');
  const tick = cssVar('--tc-text-tertiary');
  const lastIndex = values.length - 1;

  return {
    type: 'bar',
    data: {
      labels,
      datasets: [
        {
          type: 'line',
          data: values,
          borderColor: accent,
          backgroundColor: accent,
          pointBackgroundColor: accent,
          pointRadius: 3,
          tension: 0.3,
          fill: false,
          order: 0,
        },
        {
          data: values,
          backgroundColor: values.map((_, i) => (i === lastIndex ? accent : muted)),
          borderRadius: 4,
          order: 1,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: { beginAtZero: true, grid: { color: grid }, ticks: { color: tick, font: { size: 10 } } },
        x: { grid: { display: false }, ticks: { color: tick, font: { size: 10 } } },
      },
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { label: (item) => `${item.formattedValue}${valueSuffix}` } },
      },
    },
  };
}

function buildDoughnutConfig(labels: string[], values: number[], colors: string[]): ChartConfiguration<'doughnut'> {
  return {
    type: 'doughnut',
    data: { labels, datasets: [{ data: values, backgroundColor: colors, borderColor: cssVar('--tc-surface-raised'), borderWidth: 2 }] },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      cutout: '68%',
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { label: (item) => `${item.label}: ${item.formattedValue}` } },
      },
    },
  };
}

@Component({
  selector: 'app-dashboard',
  imports: [RouterLink, StatCardComponent, EmptyStateComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss',
})
export class DashboardComponent {
  private readonly fleetService = inject(FleetService);
  private readonly opsService = inject(OpsService);
  private readonly billingService = inject(BillingService);
  private readonly reportsService = inject(ReportsService);
  private readonly authService = inject(AuthService);

  // Revenue/expense/trend data comes from ReportsController, which the
  // backend gates to Admin/Manager ([Authorize(Roles = "Admin,Manager")]) -
  // a plain User role would 403 on all of it. Rather than fire those
  // requests for everyone and let the error interceptor toast a wall of
  // "forbidden" messages, this dashboard simply doesn't request (or render)
  // that slice of the layout for a User - see loadDashboard().
  readonly canViewReports = computed(() => {
    const roles = this.authService.getRoles();
    return roles.includes('Admin') || roles.includes('Manager');
  });

  readonly loading = signal(true);

  private readonly trips = signal<TripModel[]>([]);
  private readonly invoices = signal<InvoiceModel[]>([]);
  private readonly customers = signal<CustomerModel[]>([]);

  readonly totalInvoiced = signal(0);
  readonly totalOutstanding = signal(0);
  readonly totalShipments = signal(0);
  readonly totalExpenses = signal(0);
  readonly vehiclesInMaintenance = signal(0);
  readonly overdueInvoiceCount = signal(0);
  readonly expiringDocumentCount = signal(0);
  readonly expiringLicenseCount = signal(0);

  private readonly revenueTrend = signal<RevenueByPeriodModel[]>([]);
  private readonly shipmentTrend = signal<ShipmentVolumeTrendModel[]>([]);
  private readonly utilisationTrend = signal<FleetUtilisationTrendModel[]>([]);
  private readonly driverSettlements = signal<DriverSettlementSummaryModel[]>([]);

  readonly activeTrips = computed(() =>
    this.trips().filter((t) => t.statusName === 'In Transit' || t.statusName === 'Scheduled'),
  );

  readonly topRoutes = computed(() => {
    const counts = new Map<string, number>();
    for (const trip of this.trips()) {
      counts.set(trip.routeName, (counts.get(trip.routeName) ?? 0) + 1);
    }
    return Array.from(counts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 6);
  });

  readonly topCustomers = computed(() => topCustomersByRevenue(this.invoices(), this.customers(), 8));

  readonly invoiceBuckets = computed(() => invoiceStatusBuckets(this.invoices()));

  private readonly revenueCanvas = viewChild<ElementRef<HTMLCanvasElement>>('revenueCanvas');
  private readonly shipmentCanvas = viewChild<ElementRef<HTMLCanvasElement>>('shipmentCanvas');
  private readonly utilisationCanvas = viewChild<ElementRef<HTMLCanvasElement>>('utilisationCanvas');
  private readonly invoiceStatusCanvas = viewChild<ElementRef<HTMLCanvasElement>>('invoiceStatusCanvas');
  private readonly driverExpensesCanvas = viewChild<ElementRef<HTMLCanvasElement>>('driverExpensesCanvas');
  private readonly topRoutesCanvas = viewChild<ElementRef<HTMLCanvasElement>>('topRoutesCanvas');

  private revenueChart?: Chart;
  private shipmentChart?: Chart;
  private utilisationChart?: Chart;
  private invoiceStatusChart?: Chart;
  private driverExpensesChart?: Chart;
  private topRoutesChart?: Chart;

  constructor() {
    this.loadDashboard();

    effect(() => {
      const canvas = this.revenueCanvas()?.nativeElement;
      const data = this.revenueTrend();
      if (!canvas || data.length === 0) return;
      this.revenueChart?.destroy();
      this.revenueChart = new Chart(
        canvas,
        buildTrendBarConfig(data.map((d) => d.periodLabel), data.map((d) => d.totalInvoiced), ''),
      );
    });

    effect(() => {
      const canvas = this.shipmentCanvas()?.nativeElement;
      const data = this.shipmentTrend();
      if (!canvas || data.length === 0) return;
      this.shipmentChart?.destroy();
      this.shipmentChart = new Chart(
        canvas,
        buildTrendBarConfig(data.map((d) => d.periodLabel), data.map((d) => d.shipmentCount), ''),
      );
    });

    effect(() => {
      const canvas = this.utilisationCanvas()?.nativeElement;
      const data = this.utilisationTrend();
      if (!canvas || data.length === 0) return;
      this.utilisationChart?.destroy();
      this.utilisationChart = new Chart(
        canvas,
        buildTrendBarConfig(data.map((d) => d.periodLabel), data.map((d) => d.utilisationPercent), '%'),
      );
    });

    effect(() => {
      const canvas = this.invoiceStatusCanvas()?.nativeElement;
      const buckets = this.invoiceBuckets();
      const total = buckets.paid + buckets.partial + buckets.unpaid;
      if (!canvas || total === 0) return;
      this.invoiceStatusChart?.destroy();
      this.invoiceStatusChart = new Chart(
        canvas,
        buildDoughnutConfig(
          ['Paid', 'Partially Paid', 'Unpaid'],
          [buckets.paid, buckets.partial, buckets.unpaid],
          [cssVar('--tc-color-success'), cssVar('--tc-color-warning'), cssVar('--tc-divider')],
        ),
      );
    });

    effect(() => {
      const canvas = this.driverExpensesCanvas()?.nativeElement;
      const data = [...this.driverSettlements()]
        .filter((d) => d.totalExpenses > 0)
        .sort((a, b) => b.totalExpenses - a.totalExpenses)
        .slice(0, 6);
      if (!canvas || data.length === 0) return;
      this.driverExpensesChart?.destroy();
      this.driverExpensesChart = new Chart(
        canvas,
        buildTrendBarConfig(data.map((d) => d.fullName), data.map((d) => d.totalExpenses), ''),
      );
    });

    effect(() => {
      const canvas = this.topRoutesCanvas()?.nativeElement;
      const data = this.topRoutes();
      if (!canvas || data.length === 0) return;
      this.topRoutesChart?.destroy();
      this.topRoutesChart = new Chart(
        canvas,
        buildTrendBarConfig(data.map(([label]) => label), data.map(([, value]) => value), ''),
      );
    });
  }

  private loadDashboard(): void {
    const today = new Date();
    const monthAgo = new Date();
    monthAgo.setDate(today.getDate() - 30);
    const weekAhead = new Date();
    weekAhead.setDate(today.getDate() + 7);

    const fromDate = toIsoDate(monthAgo);
    const toDate = toIsoDate(today);

    forkJoin({
      vehicles: this.fleetService.getVehicles(1, 1000),
      trips: this.opsService.getTrips(
        { fromDate: fromDate + 'T00:00:00', toDate: toIsoDate(weekAhead) + 'T23:59:59' },
        1,
        1000,
      ),
      shipments: this.opsService.getShipments({}),
      invoiceSummary: this.billingService.getInvoiceSummary(fromDate, toDate),
      invoices: this.billingService.getInvoices({}),
      customers: this.billingService.getCustomers(false),
      expiringDocuments: this.fleetService.getExpiringVehicleDocuments(30),
      expiringLicenses: this.fleetService.getExpiringDriverLicenses(30),
      // Admin/Manager-only (see canViewReports) - of(null) for everyone else
      // so forkJoin still completes instead of erroring the whole dashboard.
      revenue: this.canViewReports()
        ? this.reportsService.getRevenueByPeriod(6).pipe(catchError(() => of([])))
        : of([]),
      shipmentTrend: this.canViewReports()
        ? this.reportsService.getShipmentVolumeTrend(6).pipe(catchError(() => of([])))
        : of([]),
      utilisationTrend: this.canViewReports()
        ? this.reportsService.getFleetUtilisationTrend(6).pipe(catchError(() => of([])))
        : of([]),
      driverSettlements: this.canViewReports()
        ? this.reportsService.getDriverSettlementSummary().pipe(catchError(() => of([])))
        : of([]),
    }).subscribe({
      next: ({
        vehicles,
        trips,
        shipments,
        invoiceSummary,
        invoices,
        customers,
        expiringDocuments,
        expiringLicenses,
        revenue,
        shipmentTrend,
        utilisationTrend,
        driverSettlements,
      }) => {
        this.vehiclesInMaintenance.set(vehicles.items.filter((v) => v.statusName === 'In Maintenance').length);
        this.trips.set(trips.items);
        this.totalShipments.set(shipments.length);
        this.invoices.set(invoices);
        this.customers.set(customers);
        this.totalInvoiced.set(invoiceSummary.totalInvoiced);
        this.totalOutstanding.set(invoiceSummary.totalOutstanding);
        this.overdueInvoiceCount.set(invoices.filter((i) => i.statusName === 'Overdue').length);
        this.expiringDocumentCount.set(expiringDocuments.length);
        this.expiringLicenseCount.set(expiringLicenses.length);
        this.revenueTrend.set(revenue);
        this.shipmentTrend.set(shipmentTrend);
        this.utilisationTrend.set(utilisationTrend);
        this.driverSettlements.set(driverSettlements);
        this.totalExpenses.set(driverSettlements.reduce((sum, d) => sum + d.totalExpenses, 0));
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
}
