import { ComponentFixture, TestBed } from '@angular/core/testing';

import { BulkUpload } from './bulk-upload';

describe('BulkUpload', () => {
  let component: BulkUpload;
  let fixture: ComponentFixture<BulkUpload>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [BulkUpload]
    })
    .compileComponents();

    fixture = TestBed.createComponent(BulkUpload);
    component = fixture.componentInstance;
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
