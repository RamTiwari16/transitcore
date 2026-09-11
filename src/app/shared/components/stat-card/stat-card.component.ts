import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';

export type StatCardTone = 'primary' | 'success' | 'warning' | 'danger' | 'info';

@Component({
  selector: 'app-stat-card',
  imports: [MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './stat-card.component.html',
  styleUrl: './stat-card.component.scss',
})
export class StatCardComponent {
  readonly label = input.required<string>();
  readonly value = input.required<string>();
  readonly icon = input<string>('insights');
  readonly tone = input<StatCardTone>('primary');
  readonly hint = input<string>();
}
