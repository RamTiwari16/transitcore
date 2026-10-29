import { Injectable, signal } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class LoadingService {
  private pendingRequests = 0;
  readonly isLoading = signal(false);

  start(): void {
    this.pendingRequests++;
    this.isLoading.set(true);
  }

  stop(): void {
    this.pendingRequests = Math.max(0, this.pendingRequests - 1);
    this.isLoading.set(this.pendingRequests > 0);
  }
}
