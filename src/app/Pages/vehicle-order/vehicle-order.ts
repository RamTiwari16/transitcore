import { Component, ChangeDetectorRef, NgZone } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { VehicleOrderRow, VehicleOrderService } from '../../services/vehicle-order-service';


@Component({
  selector: 'app-vehicle-order',
  imports: [CommonModule, FormsModule],
  templateUrl: './vehicle-order.html',
  styleUrl: './vehicle-order.scss',
})
export class VehicleOrder {
  Math = Math;
  // ── Date filter ───────────────────────────────────
  fromDate: string = '';
  toDate: string = '';

  // ── State ─────────────────────────────────────────
  isLoading = false;
  errorMsg = '';
  searched = false;

  // ── Data ──────────────────────────────────────────
  allData: VehicleOrderRow[] = [];
  filteredData: VehicleOrderRow[] = [];
  pagedData: VehicleOrderRow[] = [];

  // ── Search ────────────────────────────────────────
  searchTerm = '';

  // ── Pagination ────────────────────────────────────
  currentPage = 1;
  pageSize = 10;
  totalPages = 0;

  constructor(
    private service: VehicleOrderService,
    private cdr: ChangeDetectorRef,
    private ngZone: NgZone
  ) {
    // default to today
    const today = new Date().toISOString().split('T')[0];
    this.fromDate = today;
    this.toDate = today;
  }

  search() {
    if (!this.fromDate || !this.toDate) {
      this.errorMsg = 'Please select both From and To dates.';
      return;
    }
    this.isLoading = true;
    this.errorMsg = '';
    this.searched = false;
    debugger

    this.service
      .getByDateRange({ fromDate: this.fromDate, toDate: this.toDate })
      .subscribe({
        next: (res) => {
          this.ngZone.run(() => {
            this.isLoading = false;
            this.searched = true;
            this.allData = res.data ?? [];
            this.searchTerm = '';
            this.currentPage = 1;
            this.applyFilter();
            this.cdr.detectChanges();
          });
        },
        error: (err) => {
          this.ngZone.run(() => {
            this.isLoading = false;
            this.searched = true;
            this.errorMsg =
              err?.error?.message || 'Failed to fetch data. Please try again.';
            this.cdr.detectChanges();
          });
        },
      });
  }

  // ── Client-side search ────────────────────────────
  onSearchChange() {
    this.currentPage = 1;
    this.applyFilter();
  }

  applyFilter() {
    const term = this.searchTerm.toLowerCase().trim();
    this.filteredData = term
      ? this.allData.filter(
          (row) =>
            row.vehicleNo?.toLowerCase().includes(term) ||
            row.orderNo?.toLowerCase().includes(term)
        )
      : [...this.allData];

    this.totalPages = Math.ceil(this.filteredData.length / this.pageSize);
    if (this.totalPages === 0) this.totalPages = 1;
    this.buildPage();
  }

  buildPage() {
    const start = (this.currentPage - 1) * this.pageSize;
    this.pagedData = this.filteredData.slice(start, start + this.pageSize);
  }

  // ── Pagination controls ───────────────────────────
  goToPage(page: number) {
    if (page < 1 || page > this.totalPages) return;
    this.currentPage = page;
    this.buildPage();
  }

  get pageNumbers(): number[] {
    const pages: number[] = [];
    const start = Math.max(1, this.currentPage - 2);
    const end = Math.min(this.totalPages, this.currentPage + 2);
    for (let i = start; i <= end; i++) pages.push(i);
    return pages;
  }

  // ── Utility ───────────────────────────────────────
  formatDate(date: string): string {
    if (!date) return '-';
    return new Date(date).toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    });
  }
}