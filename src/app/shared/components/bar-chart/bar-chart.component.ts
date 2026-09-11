import { ChangeDetectionStrategy, Component, input } from '@angular/core';

export interface BarChartItem {
  label: string;
  value: number;
}

@Component({
  selector: 'app-bar-chart',
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './bar-chart.component.html',
  styleUrl: './bar-chart.component.scss',
})
export class BarChartComponent {
  readonly items = input.required<BarChartItem[]>();
  readonly maxValue = input<number>(100);
  readonly valueSuffix = input<string>('%');

  widthPercent(value: number): number {
    const max = this.maxValue();
    if (max <= 0) return 0;
    return Math.min(100, Math.max(0, (value / max) * 100));
  }
}
