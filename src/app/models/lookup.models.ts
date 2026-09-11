export interface RegionModel {
  id: number;
  name: string;
}

export interface BranchModel {
  id: number;
  name: string;
  regionId: number;
  regionName: string;
}

export interface DesignationModel {
  id: number;
  code: string;
  name: string;
}

export interface WorkingDesignationModel {
  id: number;
  name: string;
}

export interface StatusCodeModel {
  id: number;
  category: string;
  code: string;
  name: string;
  sortOrder: number;
}
