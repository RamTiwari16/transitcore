import { TestBed } from '@angular/core/testing';

import { VehicleOrderService } from './vehicle-order-service';

describe('VehicleOrderService', () => {
  let service: VehicleOrderService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(VehicleOrderService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
