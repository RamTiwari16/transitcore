import { ComponentFixture, TestBed } from '@angular/core/testing';

import { VehicleOrder } from './vehicle-order';

describe('VehicleOrder', () => {
  let component: VehicleOrder;
  let fixture: ComponentFixture<VehicleOrder>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [VehicleOrder]
    })
    .compileComponents();

    fixture = TestBed.createComponent(VehicleOrder);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
