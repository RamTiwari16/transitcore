import { Role } from '../../constants/roles';

export interface NavItem {
  label: string;
  icon: string;
  path: string;
  // Omit to show to everyone; set to restrict the item to specific roles -
  // purely a UX nicety (hides links a user can't use), the real gate is
  // roleGuard on the route itself plus [Authorize(Roles=...)] on the API.
  roles?: Role[];
}

export interface NavGroup {
  label: string;
  // One icon per group, shown on the icon-only rail - hovering/clicking it
  // opens a flyout panel listing the group's items (see layout.ts/.html).
  icon: string;
  items: NavItem[];
}

export const NAV_GROUPS: NavGroup[] = [
  {
    label: 'Overview',
    icon: 'dashboard',
    items: [{ label: 'Dashboard', icon: 'dashboard', path: '/dashboard' }],
  },
  {
    label: 'Fleet',
    icon: 'local_shipping',
    items: [
      { label: 'Vehicles', icon: 'local_shipping', path: '/fleet/vehicles' },
      { label: 'Drivers', icon: 'badge', path: '/fleet/drivers' },
    ],
  },
  {
    label: 'Operations',
    icon: 'route',
    items: [
      { label: 'Trips', icon: 'route', path: '/ops/trips' },
      { label: 'Routes', icon: 'alt_route', path: '/ops/routes' },
      { label: 'Shipments', icon: 'inventory_2', path: '/ops/shipments' },
      { label: 'Vehicle Orders', icon: 'assignment', path: '/vehicle-order' },
      { label: 'Bulk Upload', icon: 'upload_file', path: '/bulk-upload' },
    ],
  },
  {
    label: 'Billing',
    icon: 'receipt_long',
    items: [
      { label: 'Invoices', icon: 'receipt_long', path: '/billing/invoices' },
      { label: 'Customers', icon: 'groups', path: '/billing/customers' },
      { label: 'Vendors', icon: 'local_shipping', path: '/vendors' },
      { label: 'Rate Cards', icon: 'price_change', path: '/billing/rate-cards' },
      { label: 'Claims', icon: 'report_problem', path: '/claims' },
      { label: 'Aging Report', icon: 'schedule', path: '/billing/invoices/aging-report' },
    ],
  },
  {
    label: 'Insights',
    icon: 'insights',
    items: [{ label: 'Reports', icon: 'insights', path: '/reports', roles: ['Admin', 'Manager'] }],
  },
  {
    label: 'Admin',
    icon: 'admin_panel_settings',
    items: [
      { label: 'Users', icon: 'manage_accounts', path: '/admin/users', roles: ['Admin'] },
      { label: 'Master Data', icon: 'tune', path: '/admin/master-data', roles: ['Admin'] },
    ],
  },
];
