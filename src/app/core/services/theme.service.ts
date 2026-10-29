import { Injectable, signal } from '@angular/core';

export type ThemeMode = 'light' | 'dark' | 'system';

const STORAGE_KEY = 'tc-theme';

@Injectable({ providedIn: 'root' })
export class ThemeService {
  readonly mode = signal<ThemeMode>(this.readStoredMode());

  constructor() {
    this.apply(this.mode());
  }

  setMode(mode: ThemeMode): void {
    this.mode.set(mode);
    localStorage.setItem(STORAGE_KEY, mode);
    this.apply(mode);
  }

  toggle(): void {
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark'
      || (this.mode() === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    this.setMode(isDark ? 'light' : 'dark');
  }

  private apply(mode: ThemeMode): void {
    if (mode === 'system') {
      document.documentElement.removeAttribute('data-theme');
    } else {
      document.documentElement.setAttribute('data-theme', mode);
    }
  }

  private readStoredMode(): ThemeMode {
    const stored = localStorage.getItem(STORAGE_KEY);
    // Defaults to 'light', not 'system' - the app was auto-following the
    // OS/browser's dark-mode preference for anyone who'd never touched the
    // toggle, which reads as "randomly going dark" to a user who never
    // asked for dark mode. Explicitly picking 'dark' via the toggle still
    // works and still persists (see setMode below); this only changes what
    // happens before that first explicit choice.
    return stored === 'light' || stored === 'dark' ? stored : 'light';
  }
}
