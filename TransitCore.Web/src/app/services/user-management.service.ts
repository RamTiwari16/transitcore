import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import {
  CreateUserRequest,
  ResetPasswordRequest,
  RoleModel,
  UpdateUserRequest,
  UserDetailModel,
  UserFilter,
  UserSummaryModel,
} from '../models/user-management.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class UserManagementService {
  private readonly api = inject(ApiService);

  getUsers(filter: UserFilter = {}): Observable<UserSummaryModel[]> {
    return this.api
      .get<ApiResponse<UserSummaryModel[]>>(ApiRoutes.Users, filter)
      .pipe(map((res) => res.data));
  }

  getUserById(userId: number): Observable<UserDetailModel> {
    return this.api
      .get<ApiResponse<UserDetailModel>>(`${ApiRoutes.Users}/${userId}`)
      .pipe(map((res) => res.data));
  }

  createUser(request: CreateUserRequest): Observable<number> {
    return this.api
      .post<ApiResponse<number>>(ApiRoutes.Users, request)
      .pipe(map((res) => res.data));
  }

  updateUser(request: UpdateUserRequest): Observable<void> {
    return this.api.put<ApiResponse<string>>(ApiRoutes.Users, request).pipe(map(() => undefined));
  }

  getRoles(): Observable<RoleModel[]> {
    return this.api.get<ApiResponse<RoleModel[]>>(ApiRoutes.Roles).pipe(map((res) => res.data));
  }

  resetPassword(userId: number, request: ResetPasswordRequest): Observable<void> {
    return this.api
      .post<ApiResponse<string>>(`${ApiRoutes.Users}/${userId}/reset-password`, request)
      .pipe(map(() => undefined));
  }
}
