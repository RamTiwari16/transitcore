// Central role list - the three roles the backend's AuthResultData.roles can
// contain (seeded in auth.Roles: Admin/Manager/User). Keep this in sync with
// whatever the backend actually issues; it's the single place
// roleGuard/HasPermissionDirective/UI checks read from.
export const ROLES = ['Admin', 'Manager', 'User'] as const;
export type Role = (typeof ROLES)[number];
