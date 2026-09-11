import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

import { ApiRoutes } from '../constants/apiRoutes';
import { ApiService } from './ApiService';
import { CryptoUtil } from './crypto.util';

export interface LoginPayload {
  email: string;
  password: string;
}

export interface AuthResultData {
  userId: number;
  email: string;
  displayName: string;
  roles: string[];
  accessToken: string;
  expiresAtUtc: string;
}

export interface LoginResponse {
  success: boolean;
  message: string;
  data: AuthResultData;
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

  /** Get decrypted user data from localStorage */
  getUserData(): AuthResultData | null {
    const encrypted = localStorage.getItem(this.storageKey);
    if (!encrypted) return null;

    try {
      return CryptoUtil.decryptData(encrypted);
    } catch (err) {
      console.error('Failed to decrypt userData:', err);
      return null;
    }
  }

  /** Get the user's primary role, if any */
  getRole(): string | null {
    const userData = this.getUserData();
    return userData?.roles?.[0] ?? null;
  }

  /** Clear user data (logout) */
  logout(): void {
    localStorage.removeItem(this.storageKey);
  }
}
