import { inject } from '@angular/core';
import { CanDeactivateFn } from '@angular/router';
import { ConfirmDialogService } from '../services/confirm-dialog.service';

export interface CanComponentDeactivate {
  hasUnsavedChanges(): boolean;
}

export const unsavedChangesGuard: CanDeactivateFn<CanComponentDeactivate> = (component) => {
  if (!component.hasUnsavedChanges()) {
    return true;
  }

  const confirmDialog = inject(ConfirmDialogService);

  return confirmDialog.confirm({
    title: 'Discard unsaved changes?',
    message: 'You have unsaved changes on this page. Leaving now will discard them.',
    confirmLabel: 'Discard changes',
    cancelLabel: 'Stay on page',
    destructive: true,
  });
};
