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
  gradientId: string;
}

const RADIUS = 15.9155;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;
// Rather than rotate the whole <svg> to move the start point to 12 o'clock,
// the quarter turn is baked into each segment's dash offset instead.
const QUARTER_TURN = CIRCUMFERENCE / 4;

let nextInstanceId = 0;

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

  // Gradient <defs> need document-unique ids - two donut charts on the same
  // page (e.g. trips + invoices) would otherwise collide on "seg-0", "seg-1".
  private readonly instanceId = nextInstanceId++;

  readonly total = computed(() => this.items().reduce((sum, item) => sum + item.value, 0));

  readonly segments = computed<DonutSegment[]>(() => {
    const total = this.total();
    if (total <= 0) return [];

    let cumulative = 0;
    return this.items()
      .filter((item) => item.value > 0)
      .map((item, index) => {
        const percent = (item.value / total) * 100;
        const dashArray = `${(percent / 100) * CIRCUMFERENCE} ${CIRCUMFERENCE}`;
        const dashOffset = QUARTER_TURN - (cumulative / 100) * CIRCUMFERENCE;
        cumulative += percent;
        return { ...item, percent, dashArray, dashOffset, gradientId: `tc-donut-${this.instanceId}-${index}` };
      });
  });
}
