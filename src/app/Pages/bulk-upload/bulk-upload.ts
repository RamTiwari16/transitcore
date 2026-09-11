import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTableModule } from '@angular/material/table';
import * as XLSX from 'xlsx';
import { VehicleOrderService } from '../../services/vehicle-order-service';

interface ExcelRow {
  vehicleNo: string;
  orderNo: string;
}

@Component({
  selector: 'app-bulk-upload',
  imports: [MatButtonModule, MatIconModule, MatTableModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './bulk-upload.html',
  styleUrl: './bulk-upload.scss',
})
export class BulkUpload {
  readonly selectedFile = signal<File | null>(null);
  readonly isDragging = signal(false);
  readonly isLoading = signal(false);
  readonly errorMsg = signal('');
  readonly successMsg = signal('');
  readonly previewData = signal<ExcelRow[]>([]);
  readonly displayedColumns = ['index', 'vehicleNo', 'orderNo'];

  constructor(private vehicleOrderService: VehicleOrderService) {}

  onDragOver(e: DragEvent): void {
    e.preventDefault();
    this.isDragging.set(true);
  }

  onDragLeave(): void {
    this.isDragging.set(false);
  }

  onDrop(e: DragEvent): void {
    e.preventDefault();
    this.isDragging.set(false);
    const file = e.dataTransfer?.files[0];
    if (file) this.setFile(file);
  }

  onFileSelected(e: Event): void {
    const input = e.target as HTMLInputElement;
    if (input.files?.length) this.setFile(input.files[0]);
    input.value = '';
  }

  setFile(file: File): void {
    const ext = file.name.split('.').pop()?.toLowerCase();
    if (ext !== 'xlsx' && ext !== 'xls') {
      this.errorMsg.set('Only Excel files (.xlsx, .xls) are allowed.');
      this.selectedFile.set(null);
      this.previewData.set([]);
      return;
    }
    this.errorMsg.set('');
    this.successMsg.set('');
    this.selectedFile.set(file);
    this.parseExcel(file);
  }

  parseExcel(file: File): void {
    const reader = new FileReader();

    reader.onload = (e) => {
      const data = new Uint8Array(e.target?.result as ArrayBuffer);
      const workbook = XLSX.read(data, { type: 'array' });
      const sheet = workbook.Sheets[workbook.SheetNames[0]];
      const rows: unknown[][] = XLSX.utils.sheet_to_json(sheet, { header: 1 });

      const parsed = rows
        .slice(1)
        .filter((row) => row[0] || row[1])
        .map((row) => ({
          vehicleNo: row[0]?.toString().trim() ?? '',
          orderNo: row[1]?.toString().trim() ?? '',
        }));

      this.previewData.set(parsed);

      if (parsed.length === 0) {
        this.errorMsg.set('No data rows found in the file.');
      }
    };

    reader.onerror = () => {
      this.errorMsg.set('Failed to read file. Please try again.');
    };

    reader.readAsArrayBuffer(file);
  }

  removeFile(): void {
    this.selectedFile.set(null);
    this.previewData.set([]);
    this.errorMsg.set('');
    this.successMsg.set('');
  }

  downloadTemplate(): void {
    const templateData = [
      ['OrderNo', 'VehicleNo'],
      ['ORD-001', 'MH12AB1234'],
      ['ORD-002', 'DL01CD5678'],
    ];

    const worksheet = XLSX.utils.aoa_to_sheet(templateData);
    worksheet['!cols'] = [{ wch: 20 }, { wch: 20 }];

    const workbook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(workbook, worksheet, 'VehicleOrder');
    XLSX.writeFile(workbook, 'vehicle-order-template.xlsx');
  }

  upload(): void {
    const file = this.selectedFile();
    if (!file) {
      this.errorMsg.set('Please select a file first.');
      return;
    }

    this.isLoading.set(true);
    this.errorMsg.set('');
    this.successMsg.set('');

    this.vehicleOrderService.bulkUpload(file).subscribe({
      next: (res) => {
        this.isLoading.set(false);
        this.successMsg.set(res.message);
        this.selectedFile.set(null);
        this.previewData.set([]);
      },
      error: (err) => {
        this.isLoading.set(false);
        this.errorMsg.set(err?.error?.message || 'Upload failed. Please try again.');
      },
    });
  }

  formatFileSize(file: File): string {
    return `${(file.size / 1024).toFixed(1)} KB`;
  }
}
