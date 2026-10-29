import { Injectable } from '@angular/core';
import { HttpClient, HttpParams, HttpHeaders, HttpResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class ApiService {

  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  // --------------------
  // 🔹 Generic GET
  // --------------------
  get<T>(url: string, params?: any, headers?: HttpHeaders): Observable<T> {
    let httpParams = new HttpParams();

    if (params) {
      Object.keys(params).forEach(key => {
        const value = params[key];
        if (value !== undefined && value !== null && value !== '') {
          httpParams = httpParams.set(key, value);
        }
      });
    }

    return this.http.get<T>(`${this.apiUrl}${url}`, {
      params: httpParams,
      headers
    }).pipe(catchError(this.handleError));
  }

  // --------------------
  // 🔹 GET by Id
  // --------------------
  getById<T>(url: string, id: number | string): Observable<T> {
    return this.http.get<T>(`${this.apiUrl}${url}/${id}`)
      .pipe(catchError(this.handleError));
  }

  // --------------------
  // 🔹 POST
  // --------------------
  post<T>(url: string, body: any, headers?: HttpHeaders): Observable<T> {
    return this.http.post<T>(`${this.apiUrl}${url}`, body, { headers })
      .pipe(catchError(this.handleError));
  }

  // --------------------
  // 🔹 POST multipart/form-data (file upload)
  // --------------------
  postFormData<T>(url: string, formData: FormData): Observable<T> {
    // No Content-Type header set here deliberately - the browser sets
    // multipart/form-data with the right boundary itself when the body is a
    // FormData; setting it manually strips the boundary and the server
    // can't parse the parts.
    return this.http.post<T>(`${this.apiUrl}${url}`, formData).pipe(catchError(this.handleError));
  }

  // --------------------
  // 🔹 POST for file download (Blob)
  // --------------------
  postBlob(url: string, body: any): Observable<HttpResponse<Blob>> {
    return this.http.post(`${this.apiUrl}${url}`, body, {
      observe: 'response',
      responseType: 'blob'
    }).pipe(catchError(this.handleError));
  }

  // --------------------
  // 🔹 GET for file download (Blob)
  // --------------------
  getBlob(url: string): Observable<Blob> {
    return this.http.get(`${this.apiUrl}${url}`, {
      responseType: 'blob'
    }).pipe(catchError(this.handleError));
  }

  // --------------------
  // 🔹 PUT
  // --------------------
  put<T>(url: string, body: any): Observable<T> {
    return this.http.put<T>(`${this.apiUrl}${url}`, body)
      .pipe(catchError(this.handleError));
  }

  // --------------------
  // 🔹 DELETE
  // --------------------
  delete<T>(url: string): Observable<T> {
    return this.http.delete<T>(`${this.apiUrl}${url}`)
      .pipe(catchError(this.handleError));
  }

  // --------------------
  // 🔹 Error Handler
  // --------------------
  private handleError(error: any) {
    console.error('API Error:', error);
    return throwError(() => error.error || 'Server error');
  }
}
