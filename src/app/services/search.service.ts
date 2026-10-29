import { Injectable, inject } from '@angular/core';
import { Observable, map } from 'rxjs';
import { ApiRoutes } from '../constants/apiRoutes';
import { ApiResponse } from '../models/api-response';
import { SearchResultModel } from '../models/search.models';
import { ApiService } from './ApiService';

@Injectable({ providedIn: 'root' })
export class SearchService {
  private readonly api = inject(ApiService);

  search(term: string): Observable<SearchResultModel[]> {
    return this.api
      .get<ApiResponse<SearchResultModel[]>>(ApiRoutes.Search, { q: term })
      .pipe(map((res) => res.data));
  }
}
