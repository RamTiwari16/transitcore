import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { DecimalPipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { ReportsService } from '../../services/reports.service';
import { OpsService } from '../../services/ops.service';
import { ExpiringEwayBillModel } from '../../models/ops.models';
import {
  DriverSettlementSummaryModel,
  EmptyKmReportModel,
  FleetUtilisationTrendModel,
  RevenueByPeriodModel,
  ShipmentVolumeTrendModel,
  VehicleAvailabilityModel,
} from '../../models/reports.models';
import { BarChartComponent, BarChartItem } from '../../shared/components/bar-chart/bar-chart.component';
import { EmptyStateComponent } from '../../shared/components/empty-state/empty-state.component';
import { toLocalIsoDate } from '../../shared/util/date';

@Component({
  selector: 'app-reports',
  imports: [RouterLink, DecimalPipe, BarChartComponent, EmptyStateComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './reports.component.html',
  styleUrl: './reports.component.scss',
})
export class ReportsComponent {
  private readonly reportsService = inject(ReportsService);
  private readonly opsService = inject(OpsService);

  readonly loading = signal(true);

  readonly revenue = signal<RevenueByPeriodModel[]>([]);
  readonly fleetUtilisation = signal<FleetUtilisationTrendModel[]>([]);
  readonly shipmentVolume = signal<ShipmentVolumeTrendModel[]>([]);
  readonly driverSettlements = signal<DriverSettlementSummaryModel[]>([]);
  readonly emptyKmReport = signal<EmptyKmReportModel[]>([]);
  readonly vehiclesBecomingAvailable = signal<VehicleAvailabilityModel[]>([]);
  readonly expiringEwayBills = signal<ExpiringEwayBillModel[]>([]);

  readonly revenueChartData = computed<BarChartItem[]>(() =>
    this.revenue().map((r) => ({ label: r.periodLabel, value: r.totalInvoiced })),
  );
  readonly revenueMaxValue = computed(() => Math.max(1, ...this.revenue().map((r) => r.totalInvoiced)));

  readonly fleetUtilisationChartData = computed<BarChartItem[]>(() =>
    this.fleetUtilisation().map((f) => ({ label: f.periodLabel, value: f.utilisationPercent })),
  );

  readonly shipmentVolumeChartData = computed<BarChartItem[]>(() =>
    this.shipmentVolume().map((s) => ({ label: s.periodLabel, value: s.shipmentCount })),
  );
  readonly shipmentVolumeMaxValue = computed(() => Math.max(1, ...this.shipmentVolume().map((s) => s.shipmentCount)));

  constructor() {
    this.reportsService.getRevenueByPeriod().subscribe((data) => this.revenue.set(data));
    this.reportsService.getFleetUtilisationTrend().subscribe((data) => this.fleetUtilisation.set(data));
    this.reportsService.getShipmentVolumeTrend().subscribe((data) => this.shipmentVolume.set(data));
    this.reportsService.getDriverSettlementSummary().subscribe({
      next: (data) => {
        this.driverSettlements.set(data);
        this.loading.set(false);
      },
      error: () => this.loading.set(false),
    });

    const today = new Date();
    const threeMonthsAgo = new Date();
    threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);
    this.reportsService
      .getEmptyKmReport(toLocalIsoDate(threeMonthsAgo), toLocalIsoDate(today))
      .subscribe((data) => this.emptyKmReport.set(data));

    this.reportsService.getVehiclesBecomingAvailable().subscribe((data) => this.vehiclesBecomingAvailable.set(data));

    this.opsService.getExpiringEwayBills(7).subscribe((data) => this.expiringEwayBills.set(data));
  }

  formatDateTime(value: string | null): string {
    if (!value) return '-';
    return new Date(value).toLocaleString('en-IN', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(value);
  }
}
