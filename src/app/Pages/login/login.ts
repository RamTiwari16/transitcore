  // import { Component, OnInit } from '@angular/core';
  // import { Router } from '@angular/router';
  // import { MsalService } from '@azure/msal-angular';

  // import { AuthService } from '../../services/auth-service';
  // import { CryptoUtil } from '../../services/crypto.util';
  // import { AuthenticationResult, AccountInfo } from '@azure/msal-browser';
  // import { ToastrService } from 'ngx-toastr';

  // @Component({
  //   selector: 'app-login',
  //   standalone: true,
  //   templateUrl: './login.html',
  //   styleUrl: './login.scss'
  // })
  // export class Login implements OnInit {

  //   isSubmitting = false;

  //   constructor(
      
  //     private authService: AuthService,
  //     private router: Router,
  //     private toastr: ToastrService
  //   ) {}

  //   ngOnInit(): void {
    
  //   }
  //   // ngOnInit(): void {
  //   //   this.msalService.handleRedirectObservable().subscribe({
  //   //     next: (result: AuthenticationResult | null) => {
  //   //       if (result?.account) {
  //   //         this.msalService.instance.setActiveAccount(result.account);
  //   //         this.loginWithBackend(result.account);
  //   //       } else {
  //   //         const account = this.msalService.instance.getActiveAccount() 
  //   //           || this.msalService.instance.getAllAccounts()[0];

  //   //         if (account) {
  //   //           this.msalService.instance.setActiveAccount(account);
  //   //           this.loginWithBackend(account);
  //   //         }
  //   //       }
  //   //     },
  //   //     error: (error) => {
  //   //       console.error('MSAL Redirect Error:', error);
  //   //       this.toastr.error('Microsoft login failed');
  //   //     }
  //   //   });
  //   // }

  //   // continueWithMicrosoft(): void {
  //   //   this.msalService.loginRedirect({
  //   //     scopes: ['user.read'],
  //   //     prompt: 'select_account'
  //   //   });
  //   // }
  //   continueWithMicrosoft(): void {
    
  //   }

  //   private loginWithBackend(account: AccountInfo): void {
  //     this.isSubmitting = true;

  //     const payload = {
  //       email: account.username
  //     };

  //     this.authService.login(payload).subscribe({
  //       next: (res) => {
  //         if (res?.data?.token) {
  //           const encryptedUser = CryptoUtil.encryptData(res.data);

  //           localStorage.setItem('token', res.data.token);
  //           sessionStorage.setItem('authToken', res.data.token);
  //           localStorage.setItem('userData', encryptedUser);

  //           this.toastr.success('Login successful');
  //           this.router.navigate(['/dashboard']);
  //         } else {
  //           this.toastr.error('Invalid login response');
  //         }
  //       },
  //       error: () => {
  //         this.toastr.error('Authentication failed');
  //       },
  //       complete: () => {
  //         this.isSubmitting = false;
  //       }
  //     });
  //   }
  // }

  import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth-service';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { CryptoUtil } from '../../services/crypto.util';
import { MatIconModule } from '@angular/material/icon';


@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule,MatIconModule],
  templateUrl: './login.html',
  styleUrls: ['./login.scss']
})
export class Login {
  email = '';
  password = '';
  showPassword = false;
  isLoading = false;
  errorMsg = '';

  constructor(private authService: AuthService, private router: Router) {}

  login() {
    // this.router.navigate(['/bulkupload']);

    
    this.errorMsg = '';

    if (!this.email || !this.password) {
      this.errorMsg = 'Please enter both email and password.';
      return;
    }
    

    this.isLoading = true;
   
    this.authService.login({ email: this.email, password: this.password }).subscribe({
      next: (res) => {
        this.isLoading = false;
        localStorage.setItem('authToken', res.data.accessToken);

        const encryptedUser = CryptoUtil.encryptData(res.data);
        localStorage.setItem('userData', encryptedUser);
        this.router.navigate(['/bulkupload']);
      },
      error: (err) => {
        this.isLoading = false;
        this.errorMsg = err?.error?.message || 'Invalid email or password.';
      }
    });
  }

  continueWithMicrosoft() {
    // your existing Microsoft SSO logic
  }
}