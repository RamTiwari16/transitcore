import { Component, NgZone, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import * as XLSX from 'xlsx';
import { VehicleOrderService } from '../../services/vehicle-order-service';


interface ExcelRow {
  vehicleNo: string;
  orderNo: string;
}

@Component({
  selector: 'app-bulk-upload',
  imports: [CommonModule],
  templateUrl: './bulk-upload.html',
  styleUrl: './bulk-upload.scss',
})
export class BulkUpload {
  selectedFile: File | null = null;
  isDragging = false;
  isLoading = false;
  errorMsg = '';
  successMsg = '';
  previewData: ExcelRow[] = [];

  constructor(
    private vehicleOrderService: VehicleOrderService,
    private ngZone: NgZone,
    private cdr: ChangeDetectorRef    // ← add this
  ) { }

  onDragOver(e: DragEvent) {
    e.preventDefault();
    this.isDragging = true;
  }

  onDragLeave() {
    this.isDragging = false;
  }

  onDrop(e: DragEvent) {
    e.preventDefault();
    this.isDragging = false;
    const file = e.dataTransfer?.files[0];
    if (file) this.setFile(file);
  }

  onFileSelected(e: Event) {
    const input = e.target as HTMLInputElement;
    if (input.files?.length) this.setFile(input.files[0]);
    // reset input so same file can be re-selected
    (e.target as HTMLInputElement).value = '';
  }

  setFile(file: File) {
    const ext = file.name.split('.').pop()?.toLowerCase();
    if (ext !== 'xlsx' && ext !== 'xls') {
      this.errorMsg = 'Only Excel files (.xlsx, .xls) are allowed.';
      this.selectedFile = null;
      this.previewData = [];
      this.cdr.detectChanges();      // ← force update
      return;
    }
    this.errorMsg = '';
    this.successMsg = '';
    this.selectedFile = file;
    this.cdr.detectChanges();        // ← force update so file name shows instantly
    this.parseExcel(file);
  }

  parseExcel(file: File) {
    const reader = new FileReader();

    reader.onload = (e: any) => {
      this.ngZone.run(() => {          // ← run inside Angular zone
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        const sheet = workbook.Sheets[workbook.SheetNames[0]];
        const rows: any[][] = XLSX.utils.sheet_to_json(sheet, { header: 1 });

        this.previewData = rows
          .slice(1)
          .filter(row => row[0] || row[1])
          .map(row => ({
            vehicleNo: row[0]?.toString().trim() ?? '',
            orderNo: row[1]?.toString().trim() ?? '',
          }));

        if (this.previewData.length === 0) {
          this.errorMsg = 'No data rows found in the file.';
        }

        this.cdr.detectChanges();     // ← force update after parsing
      });
    };

    reader.onerror = () => {
      this.ngZone.run(() => {
        this.errorMsg = 'Failed to read file. Please try again.';
        this.cdr.detectChanges();
      });
    };

    reader.readAsArrayBuffer(file);
  }

  removeFile() {
    this.selectedFile = null;
    this.previewData = [];
    this.errorMsg = '';
    this.successMsg = '';
    this.cdr.detectChanges();        // ← force update on remove
  }

  downloadTemplate() {
    const templateData = [
      ['OrderNo','VehicleNo'  ],   // header row
      ['ORD-001','MH12AB1234' ], // example row 1
      ['ORD-002','DL01CD5678' ], // example row 2
    ];

    const worksheet = XLSX.utils.aoa_to_sheet(templateData);

    // column widths
    worksheet['!cols'] = [
      { wch: 20 },  // VehicleNo column width
      { wch: 20 },  // OrderNo column width
    ];

    // style header row bold (note: basic XLSX doesn't support rich styles,
    // but column headers are set correctly)
    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'VehicleOrder');

    XLSX.writeFile(workbook, 'vehicle-order-template.xlsx');
  }

  upload() {
    if (!this.selectedFile) {
      this.errorMsg = 'Please select a file first.';
      return;
    }
    this.isLoading = true;
    this.errorMsg = '';
    this.successMsg = '';

    this.vehicleOrderService.bulkUpload(this.selectedFile).subscribe({
      next: (res) => {
        this.ngZone.run(() => {
          this.isLoading = false;
          this.successMsg = res.message;
          this.selectedFile = null;
          this.previewData = [];
          this.cdr.detectChanges();  // ← force update after upload
        });
      },
      error: (err) => {
        this.ngZone.run(() => {
          this.isLoading = false;
          this.errorMsg = err?.error?.message || 'Upload failed. Please try again.';
          this.cdr.detectChanges();  // ← force update on error
        });
      },
    });
  }
}