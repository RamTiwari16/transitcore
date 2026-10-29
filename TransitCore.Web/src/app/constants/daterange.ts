import { CommonModule } from '@angular/common';
import { Component, Output, EventEmitter, Input } from '@angular/core';
import { FormControl, FormGroup, FormsModule, ReactiveFormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatNativeDateModule } from '@angular/material/core';
import { MatDatepickerModule } from '@angular/material/datepicker';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';

export interface DateRange {
    from: Date;
    to: Date;
}

@Component({
    selector: 'app-date-range-picker',
    standalone: true,
    imports: [
        CommonModule,
        ReactiveFormsModule,
        MatDatepickerModule,
        MatInputModule,
        MatFormFieldModule,
        MatButtonModule,
        MatNativeDateModule,
        MatIconModule,
        FormsModule
    ],
    template: `
    <div class="date-range-container">
        <mat-form-field appearance="outline">
            <mat-label>Select Date Range</mat-label>
            <mat-date-range-input [formGroup]="range" [rangePicker]="picker">
                <input matStartDate formControlName="start" placeholder="Start date">
                <input matEndDate formControlName="end" placeholder="End date">
            </mat-date-range-input>
            <mat-hint>MM/DD/YYYY – MM/DD/YYYY</mat-hint>
            <mat-datepicker-toggle matIconSuffix [for]="picker"></mat-datepicker-toggle>
            <mat-date-range-picker #picker></mat-date-range-picker>

            @if(range.controls.start.hasError('matStartDateInvalid')){
            <mat-error>Invalid start date</mat-error>
            }
            @if(range.controls.start.hasError('matEndDateInvalid')){
            <mat-error>Invalid end date</mat-error>
            }
        </mat-form-field>

        <div class="actions d-none">
            <button mat-raised-button color="primary"
                    [disabled]="!range.valid || !range.value.start || !range.value.end"
                    (click)="onApplyRange()">
            Apply Date Range
            </button>
            <button mat-button (click)="onClear()">Clear</button>
        </div>
    </div>
    `,
    styles: [`
    .date-range-container { max-width: 400px; margin: 20px 0; }
    .actions { margin-top: 20px; }
    .actions button { margin-right: 10px; }
    mat-form-field { width: 100%; }
    `]
})
export class DateRangePickerComponent {
    @Input() title: string = 'Select Date Range';
    @Input() initialFromDate?: Date;
    @Input() initialToDate?: Date;

    @Output() dateRangeSelected = new EventEmitter<DateRange>();
    @Output() dateRangeCleared = new EventEmitter<void>();

    range = new FormGroup({
        start: new FormControl<Date | null>(null),
        end: new FormControl<Date | null>(null),
    });

    ngOnInit() {
        // Set initial values if provided
        if (this.initialFromDate && this.initialToDate) {
            this.range.patchValue({
                start: this.initialFromDate,
                end: this.initialToDate
            });
        }

        // Subscribe to changes for real-time updates
        this.range.valueChanges.subscribe(value => {
            if (value.start && value.end && this.range.valid) {
                this.dateRangeSelected.emit({
                    from: value.start,
                    to: value.end
                });
            }
        });
    }

    onApplyRange() {
        const { start, end } = this.range.value;
        if (start && end) {
            this.dateRangeSelected.emit({ from: start, to: end });
        }
    }

    onClear() {
        this.range.reset();
        this.dateRangeCleared.emit();
    }
}
