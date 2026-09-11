import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { Router } from '@angular/router';
import { FormControl, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from '../../services/auth-service';
import { CryptoUtil } from '../../services/crypto.util';

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

  readonly form = new FormGroup<LoginFormModel>({
    email: new FormControl('', { nonNullable: true, validators: [Validators.required, Validators.email] }),
    password: new FormControl('', { nonNullable: true, validators: [Validators.required] }),
  });

  constructor(
    private authService: AuthService,
    private router: Router,
  ) {}

  togglePasswordVisibility(): void {
    this.showPassword.update((v) => !v);
  }

  login(): void {
    this.errorMsg.set('');

    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.isLoading.set(true);
    const { email, password } = this.form.getRawValue();

    this.authService.login({ email, password }).subscribe({
      next: (res) => {
        this.isLoading.set(false);
        localStorage.setItem('authToken', res.data.accessToken);

        const encryptedUser = CryptoUtil.encryptData(res.data);
        localStorage.setItem('userData', encryptedUser);
        this.router.navigate(['/dashboard']);
      },
      error: (err) => {
        this.isLoading.set(false);
        this.errorMsg.set(err?.error?.message || 'Invalid email or password.');
      },
    });
  }
}
