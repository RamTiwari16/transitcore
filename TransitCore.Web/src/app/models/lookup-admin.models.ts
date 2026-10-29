export interface CountryModel {
  id: number;
  code: string;
  name: string;
}

export interface CreateRegionRequest {
  name: string;
}
export interface UpdateRegionRequest {
  id: number;
  name: string;
}

export interface CreateBranchRequest {
  name: string;
  code: string;
  regionId: number;
}
export interface UpdateBranchRequest {
  id: number;
  name: string;
  code: string;
  regionId: number;
}

export interface CreateDesignationRequest {
  code: string;
  name: string;
}
export interface UpdateDesignationRequest {
  id: number;
  code: string;
  name: string;
}

export interface CreateWorkingDesignationRequest {
  name: string;
}
export interface UpdateWorkingDesignationRequest {
  id: number;
  name: string;
}

export interface CreateCountryRequest {
  code: string;
  name: string;
}
export interface UpdateCountryRequest {
  id: number;
  code: string;
  name: string;
}

export interface CreateCityRequest {
  name: string;
  countryId: number;
}
export interface UpdateCityRequest {
  id: number;
  name: string;
  countryId: number;
}

export interface CreateStatusCodeRequest {
  category: string;
  code: string;
  name: string;
  sortOrder: number;
}
export interface UpdateStatusCodeRequest {
  id: number;
  category: string;
  code: string;
  name: string;
  sortOrder: number;
}

export interface CreateUnitOfMeasureRequest {
  code: string;
  name: string;
}
export interface UpdateUnitOfMeasureRequest {
  id: number;
  code: string;
  name: string;
}

export interface RequiredComplianceDocumentTypeModel {
  id: number;
  documentType: string;
  isActive: boolean;
}
export interface CreateRequiredComplianceDocumentTypeRequest {
  documentType: string;
}
export interface UpdateRequiredComplianceDocumentTypeRequest {
  id: number;
  documentType: string;
  isActive: boolean;
}
