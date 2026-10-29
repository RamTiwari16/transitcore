import { Component, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ThemeService } from './core/services/theme.service';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App {
  // Injected here (not just in the authenticated Layout shell) so it runs
  // before ANY route renders, login included - otherwise data-theme is
  // never set on /login (Layout hasn't loaded yet) and the page falls back
  // to raw `prefers-color-scheme: dark`, ignoring the app's own light/dark
  // preference entirely.
  private readonly themeService = inject(ThemeService);
}
