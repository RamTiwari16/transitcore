import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { DecimalPipe } from '@angular/common';

export interface DonutChartItem {
  label: string;
  value: number;
  color: string;
}

interface DonutSegment extends DonutChartItem {
  dashArray: string;
  dashOffset: number;
  percent: number;
}

const RADIUS = 15.9155;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

@Component({
  selector: 'app-donut-chart',
  imports: [DecimalPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './donut-chart.component.html',
  styleUrl: './donut-chart.component.scss',
})
export class DonutChartComponent {
  readonly items = input.required<DonutChartItem[]>();
  readonly centerLabel = input<string>('');

  readonly total = computed(() => this.items().reduce((sum, item) => sum + item.value, 0));

  readonly segments = computed<DonutSegment[]>(() => {
    const total = this.total();
    if (total <= 0) return [];

    let cumulative = 0;
    return this.items()
      .filter((item) => item.value > 0)
      .map((item) => {
        const percent = (item.value / total) * 100;
        const dashArray = `${(percent / 100) * CIRCUMFERENCE} ${CIRCUMFERENCE}`;
        // Segments stack clockwise from the 12 o'clock mark (the -25 base
        // offset in the template rotates the whole circle there); each one
        // starts where the previous one's cumulative percentage left off.
        const dashOffset = -1 * (cumulative / 100) * CIRCUMFERENCE;
        cumulative += percent;
        return { ...item, percent, dashArray, dashOffset };
      });
  });
}
