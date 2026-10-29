import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { Router, RouterLink } from '@angular/router';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatDialog } from '@angular/material/dialog';
import { UserManagementService } from '../../../services/user-management.service';
import { ToastService } from '../../../core/services/toast.service';
import { UserSummaryModel } from '../../../models/user-management.models';
import { DataTableColumn, DataTableComponent } from '../../../shared/components/data-table/data-table.component';
import { createClientPagedListState } from '../../../shared/util/client-paged-list-state';
import { ResetPasswordDialogComponent } from '../reset-password-dialog/reset-password-dialog.component';

@Component({
  selector: 'app-users-list',
  imports: [RouterLink, MatButtonModule, MatIconModule, MatTooltipModule, DataTableComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './users-list.component.html',
  styleUrl: './users-list.component.scss',
})
export class UsersListComponent {
  private readonly userManagementService = inject(UserManagementService);
  private readonly toast = inject(ToastService);
  private readonly router = inject(Router);
  private readonly dialog = inject(MatDialog);

  readonly columns = computed<DataTableColumn<UserSummaryModel>[]>(() => [
    { key: 'displayName', label: 'Name', sortable: true, cell: (row) => row.displayName },
    { key: 'email', label: 'Email', sortable: true, cell: (row) => row.email },
    { key: 'roleNames', label: 'Roles', cell: (row) => row.roleNames.join(', ') || '-' },
    { key: 'branchNames', label: 'Branches', cell: (row) => row.branchNames.join(', ') || '-' },
    { key: 'isActive', label: 'Status', cell: (row) => (row.isActive ? 'Active' : 'Inactive') },
  ]);

  readonly list = createClientPagedListState<UserSummaryModel>(() => this.userManagementService.getUsers());

  constructor() {
    this.list.load();
  }

  rowId = (row: UserSummaryModel): number => row.id;

  openUser(row: UserSummaryModel): void {
    this.router.navigate(['/admin/users', row.id, 'edit']);
  }

  resetPassword(row: UserSummaryModel): void {
    this.dialog
      .open(ResetPasswordDialogComponent, { width: '420px', data: { userId: row.id, displayName: row.displayName } })
      .afterClosed()
      .subscribe((newPassword: string | undefined) => {
        if (!newPassword) return;

        this.userManagementService.resetPassword(row.id, { newPassword }).subscribe({
          next: () => this.toast.success('Password reset successfully'),
        });
      });
  }
}
