import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'app-empty-state',
  imports: [MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div class="empty-state">
      <mat-icon aria-hidden="true">{{ icon() }}</mat-icon>
      <p class="empty-state__title">{{ title() }}</p>
      @if (description()) {
        <p class="empty-state__description">{{ description() }}</p>
      }
      <ng-content></ng-content>
    </div>
  `,
  styles: `
    .empty-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      padding: var(--tc-space-12) var(--tc-space-6);
      color: var(--tc-text-secondary);
    }

    mat-icon {
      font-size: 40px;
      width: 40px;
      height: 40px;
      color: var(--tc-text-tertiary);
      margin-bottom: var(--tc-space-3);
    }

    .empty-state__title {
      font-weight: var(--tc-font-weight-medium);
      color: var(--tc-text-primary);
      margin: 0;
    }

    .empty-state__description {
      font-size: var(--tc-font-size-sm);
      margin: var(--tc-space-1) 0 0;
      max-width: 32rem;
    }
  `,
})
export class EmptyStateComponent {
  readonly icon = input<string>('inbox');
  readonly title = input.required<string>();
  readonly description = input<string>();
}
