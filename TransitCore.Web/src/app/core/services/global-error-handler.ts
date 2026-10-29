import { ErrorHandler, Injectable, Injector, inject } from '@angular/core';
import { ToastService } from './toast.service';

@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  private readonly injector = inject(Injector);

  handleError(error: unknown): void {
    console.error('Unhandled error:', error);

    const toast = this.injector.get(ToastService);
    toast.error('Something went wrong. Please try again.', 'Unexpected error');
  }
}
