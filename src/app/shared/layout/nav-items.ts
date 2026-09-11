export interface NavItem {
  label: string;
  icon: string;
  path: string;
}

export interface NavGroup {
  label: string;
  items: NavItem[];
}

export const NAV_GROUPS: NavGroup[] = [
  {
    label: 'Overview',
    items: [{ label: 'Dashboard', icon: 'dashboard', path: '/dashboard' }],
  },
  {
    label: 'Fleet',
    items: [{ label: 'Vehicles', icon: 'local_shipping', path: '/fleet/vehicles' }],
  },
  {
    label: 'Operations',
    items: [
      { label: 'Trips', icon: 'route', path: '/ops/trips' },
      { label: 'Vehicle-Order Mapping', icon: 'assignment', path: '/vehicle-order' },
      { label: 'Bulk Upload', icon: 'upload_file', path: '/bulkupload' },
    ],
  },
  {
    label: 'Billing',
    items: [
      { label: 'Invoices', icon: 'receipt_long', path: '/billing/invoices' },
      { label: 'Customers', icon: 'groups', path: '/billing/customers' },
    ],
  },
];
