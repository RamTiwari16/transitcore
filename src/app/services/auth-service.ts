import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

import { ApiRoutes } from '../constants/apiRoutes';
import { ApiService } from './ApiService';
import { CryptoUtil } from './crypto.util';


export interface LoginRequest {
  email: string;
 
}

export interface LoginResponse {
  status: string;
  message: string;
  data: {
    userId: string;
    userName: string;
    password: string | null;
    role: string;
    roleName: string;
    token: string;
    email: string | null;
    createdBy: string | null;
    createdOn: string;
  };
}

export interface LoginPayload {
  email: string;
  passWord: string;
}

export interface LoginResponse {
  token: string;
  // add other fields your API returns
}

@Injectable({
  providedIn: 'root'
})

export class AuthService {
  private storageKey = 'userData';
  

  constructor(private apiService: ApiService) {}

  login(credentials: LoginPayload): Observable<LoginResponse> {
    return this.apiService.post<LoginResponse>(
      ApiRoutes.Login,
      credentials
    ).pipe(
      tap((response: LoginResponse) => {
        if (response && response.data) {
          const encrypted = CryptoUtil.encryptData(response.data);
          localStorage.setItem(this.storageKey, encrypted);
        }
      })
    );
  }

  // login(credentials: LoginRequest): Observable<LoginResponse> {
  //   return this.apiService.post<LoginResponse>(
  //     ApiRoutes.Login,
  //     credentials,
      
  //   ).pipe(
  //     tap((response: LoginResponse) => {
  //       if (response && response.data) {
  //         // Encrypt and store userData in localStorage
  //         const encrypted = CryptoUtil.encryptData(response.data);
  //         localStorage.setItem(this.storageKey, encrypted);
  //       }
  //     })
  //   );
  // }

  /** Get decrypted user data from localStorage */
  getUserData(): LoginResponse['data'] | null {
    const encrypted = localStorage.getItem(this.storageKey);
    if (!encrypted) return null;

    try {
      return CryptoUtil.decryptData(encrypted);
    } catch (err) {
      console.error('❌ Failed to decrypt userData:', err);
      return null;
    }
  }

  /** Get role directly */
  getRole(): string | null {
    const userData = this.getUserData();
    return userData ? userData.roleName : null;
  }

  /** Clear user data (logout) */
  logout(): void {
    localStorage.removeItem(this.storageKey);
  }
}

// import { Injectable } from '@angular/core';
// import { Observable } from 'rxjs';

// import { ApiRoutes } from '../constants/apiRoutes';
// import { ApiService } from './ApiService';

// export interface LoginRequest {
//   userId: string;
//   password: string;
// }


// export interface LoginResponse {
//   status: string;
//   message: string;
//   data: {
//     userId: string;
//     userName: string;
//     password: string | null;
//     role: string;
//     roleName: string;
//     token: string;
//     email: string | null;
//     createdBy: string | null;
//     createdOn: string;
//   };
// }

// @Injectable({
//   providedIn: 'root'
// })
// export class AuthService {
//   constructor(private apiService: ApiService) {}

//   login(credentials: LoginRequest): Observable<LoginResponse> {
//     return this.apiService.post<LoginResponse>(ApiRoutes.Login, credentials,undefined, 'auth');
//   }



// }
