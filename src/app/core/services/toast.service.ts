import { Injectable } from '@angular/core';
import { ToastrService } from 'ngx-toastr';

@Injectable({ providedIn: 'root' })
export class ToastService {
  constructor(private toastr: ToastrService) {}

  success(message: string, title = ''): void {
    this.toastr.success(message, title);
  }

  error(message: string, title = ''): void {
    this.toastr.error(message, title);
  }

  info(message: string, title = ''): void {
    this.toastr.info(message, title);
  }

  warning(message: string, title = ''): void {
    this.toastr.warning(message, title);
  }
}
