export interface RoleModel {
  id: number;
  name: string;
}

export interface UserFilter {
  branchId?: number;
  designationId?: number;
  workingDesignationId?: number;
}

export interface UserSummaryModel {
  id: number;
  email: string;
  displayName: string;
  empCode: string | null;
  designationId: number | null;
  designationName: string | null;
  workingDesignationId: number | null;
  workingDesignationName: string | null;
  regionId: number | null;
  regionName: string | null;
  punchLocation: string | null;
  shift: string | null;
  company: string | null;
  isActive: boolean;
  branchNames: string[];
  roleNames: string[];
}

export interface UserDetailModel {
  id: number;
  email: string;
  displayName: string;
  phoneNo: string | null;
  empCode: string | null;
  designationId: number | null;
  designationName: string | null;
  workingDesignationId: number | null;
  workingDesignationName: string | null;
  regionId: number | null;
  regionName: string | null;
  punchLocation: string | null;
  shift: string | null;
  company: string | null;
  isActive: boolean;
  createdAt: string;
  createdBy: string | null;
  branchIds: number[];
  roleIds: number[];
}

export interface CreateUserRequest {
  email: string;
  password: string;
  displayName: string;
  phoneNo?: string;
  empCode?: string;
  designationId?: number;
  workingDesignationId?: number;
  regionId?: number;
  punchLocation?: string;
  shift?: string;
  company?: string;
  branchIds: number[];
  roleIds: number[];
}

export interface UpdateUserRequest {
  userId: number;
  displayName: string;
  phoneNo?: string;
  designationId?: number;
  workingDesignationId?: number;
  regionId?: number;
  punchLocation?: string;
  shift?: string;
  company?: string;
  isActive: boolean;
  branchIds: number[];
  roleIds: number[];
}

export interface ResetPasswordRequest {
  newPassword: string;
}
