import { ChangeDetectionStrategy, Component, ElementRef, ViewChild, signal } from '@angular/core';
import { Router } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from '../../services/auth-service';
import { ToastService } from '../../core/services/toast.service';
import { AuthTransitionOriginService } from '../../core/services/auth-transition-origin.service';

interface LoginFormModel {
  email: FormControl<string>;
  password: FormControl<string>;
}

@Component({
  selector: 'app-login',
  imports: [ReactiveFormsModule, MatFormFieldModule, MatInputModule, MatButtonModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './login.html',
  styleUrls: ['./login.scss'],
})
export class Login {
  readonly showPassword = signal(false);
  readonly isLoading = signal(false);
  readonly errorMsg = signal('');
  readonly proofInitials = ['JD', 'MK', 'AR'];

  // The circular-wipe origin on success (app.config.ts) - the sign-in
  // button's own position, so it works the same whether login was
  // submitted by clicking it or pressing Enter in a field.
  @ViewChild('submitBtn', { read: ElementRef }) private submitBtn?: ElementRef<HTMLButtonElement>;

  readonly form = new FormGroup<LoginFormModel>({
    email: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.email] }),
    password: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });

  constructor(
    private authService: AuthService,
    private router: Router,
    private toast: ToastService,
    private authTransitionOrigin: AuthTransitionOriginService,
  ) {}

  togglePasswordVisibility(): void {
    this.showPassword.update((v) => !v);
  }

  // Google OAuth isn't wired up on the backend yet (email/password + JWT
  // only) - this stays a clear no-op rather than pretending to authenticate.
  continueWithGoogle(): void {
    this.toast.info('Google sign-in is not set up yet. Use email and password below.');
  }

  // No password-reset endpoint exists yet either - same honesty as above.
  forgotPassword(): void {
    this.toast.info('Password reset is not set up yet. Contact your administrator.');
  }

  login(): void {
    this.errorMsg.set('');

    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    if (this.submitBtn) {
      const rect = this.submitBtn.nativeElement.getBoundingClientRect();
      this.authTransitionOrigin.capture(rect.left + rect.width / 2, rect.top + rect.height / 2);
    }

    this.isLoading.set(true);
    const { email, password } = this.form.getRawValue();

    this.authService.login({ email, password }).subscribe({
      next: () => {
        // AuthService.login() already persisted the encrypted session as a
        // side effect (see its own tap()) - this is the only place that
        // needs to happen, so nothing further to store here.
        this.isLoading.set(false);
        this.router.navigate(['/dashboard']);
      },
      error: (err) => {
        this.isLoading.set(false);
        this.errorMsg.set(err?.error?.message || 'Invalid email or password.');
      },
    });
  }
}
