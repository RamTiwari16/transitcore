// import { Injectable } from '@angular/core';
// import { Observable } from 'rxjs';
// import { tap } from 'rxjs/operators';
// import { ApiRoutes } from '../constants/apiRoutes';
// import { ApiService } from './ApiService';


// export interface BulkUploadResponse {
//   success: boolean;
//   message: string;
//   data?: {
//     totalRecords: number;
//     uploadedBy: string;
//     uploadDate: string;
//   };
// }

// @Injectable({ providedIn: 'root' })
// export class VehicleOrderService {
//   constructor(private apiService: ApiService) {}

//   bulkUpload(file: File): Observable<BulkUploadResponse> {
//     const formData = new FormData();
//     formData.append('file', file);
//     return this.apiService.post<BulkUploadResponse>(
//       ApiRoutes.BulkUpload,   // 'VehicleOrder/bulk-upload'
//       formData
//     );
//   }
// }



import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiService } from './ApiService';

export interface BulkUploadResponse {
  success: boolean;
  message: string;
  data?: {
    totalRecords: number;
    uploadedBy: string;
    uploadDate: string;
  };
}

export interface DateRangeRequest {
  fromDate: string;
  toDate: string;
}

export interface VehicleOrderRow {
  id: number;
  vehicleNo: string;
  orderNo: string;
  uploadDate: string;
  createdByEmail: string;
}

export interface DateRangeResponse {
  success: boolean;
  message: string;
  data: VehicleOrderRow[];
}

@Injectable({ providedIn: 'root' })
export class VehicleOrderService {
  constructor(private apiService: ApiService) {}

  bulkUpload(file: File): Observable<BulkUploadResponse> {
    const formData = new FormData();
    formData.append('file', file);
    return this.apiService.post<BulkUploadResponse>(
      ApiRoutes.BulkUpload,
      formData
    );
  }

  getByDateRange(payload: DateRangeRequest): Observable<DateRangeResponse> {
    return this.apiService.post<DateRangeResponse>(
      ApiRoutes.GetByDateRange,
      payload
    );
  }
}