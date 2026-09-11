import { Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule, RouterOutlet } from '@angular/router';



import { interval, Subscription } from 'rxjs';
import { CryptoUtil } from '../../services/crypto.util';
import { ToastrService } from 'ngx-toastr';





interface MenuItem {
  id: number;
  menuText: string;
  iconClass: string;
  pageUrl?: string;
  active: number;
  role: role[];
  expanded?: boolean;
  collapsed?: boolean;
  children?: MenuItem[];
}

type role = 'superadmin' | 'admin' | 'user'

@Component({
  selector: 'app-layout',
  standalone: true,
  imports: [CommonModule, RouterModule, RouterOutlet],
  templateUrl: './layout.html',
  styleUrl: './layout.scss'
})
export class Layout implements OnInit {
  collapsed = false;
  masterExpanded = false; // Property for master submenu
  LoggedInName = 'User';
  LoggedInRole = 'superadmin';
  LoggedInRoleName = 'superadmin';
  currentRole!: role;
  loginTime: Date | null = null;
  timer: any;
  totalLoginDurationMs: number = 0;
  private subscription!: Subscription;
  userData: any;
  avatarColor: string = '#000';
  showLogoutMenu: boolean = false;

  toggleLogoutMenu(): void {
    this.showLogoutMenu = !this.showLogoutMenu;
  }





  ngOnInit(): void {
    this.avatarColor = this.getRandomColor();
    const encryptedData = localStorage.getItem('userData');
    if (encryptedData) {
      this.userData = CryptoUtil.decryptData(encryptedData);






      // update LoggedInRole dynamically from decrypted data
      const primaryRole = this.userData?.roles?.[0];
      if (primaryRole) {
        this.LoggedInRole = primaryRole.toLowerCase();
        this.LoggedInRoleName = primaryRole;
        this.LoggedInName = this.userData.email;
        this.currentRole = this.LoggedInRoleName.toLowerCase() as role;
        this.Menus = this.Menus.filter((m) => m.role.includes(this.currentRole));
        this.toastr.success('Hello ' + this.LoggedInName, 'Welcome back 👋');
      }
    } else {
      console.warn("⚠️ No userData found in localStorage");
    }
  }

  constructor(
    private router: Router, private toastr: ToastrService

  ) {

  }

  Menus: MenuItem[] = [
    {
      id: 1,
      menuText: 'vehicleOrder',
     iconClass: 'fa-solid fa-chart-column',
      pageUrl: 'vehicleOrder',
      active: 1,
      role: ['superadmin', 'admin', 'user']
    },
    // {
    //   id: 2,
    //   menuText: 'Master',
    //   iconClass: 'fas fa-cogs',
    //   active: 1,
    //   role: ['superadmin', 'admin', 'user'],
    //   expanded: false, // default collapsed
    //   children: [
    //     {
    //       id: 21,
    //       menuText: 'Register VTS',
    //       iconClass: 'fas fa-users-cog',
    //       pageUrl: 'add-Device',
    //       active: 1,
    //       role: ['superadmin', 'admin', 'user']
    //     }

    //   ]
    // },
    {
      id: 3,
      menuText: 'Bulk Upload',
      iconClass: 'fa-solid fa-upload',

      pageUrl: 'bulkupload',
      active: 1,
      role: ['superadmin', 'admin', 'user']
    }



  ];

  toggleSideNav(): void {
    this.collapsed = !this.collapsed;
    // Reset master submenu when closing sidebar
    if (!this.collapsed) {
      this.masterExpanded = false;
    }
  }

  // Method to toggle Master submenu
  toggleMaster(): void {
    if (this.collapsed) {
      this.masterExpanded = !this.masterExpanded;
    }
  }

  getBodyClass(): string {
    return this.collapsed ? 'body-trimmed' : 'body-md-screen';
  }


  getRandomColor(): string {
    const colors = [
      // Original colors
      '#FF6B6B', '#4ECDC4', '#556270', '#C44DFF', '#45B7D1',
      '#FFA500', '#6A5ACD', '#28C76F', '#EA5455', '#B8E986',

      // Light colors
      '#FF9999', '#FF8A7B', '#FF7B7B', '#FF6B9D', '#FF1493',
      '#FF69B4', '#87CEEB', '#87CEFA', '#6495ED', '#4682B4',
      '#9370DB', '#BA55D3', '#DA70D6', '#EE82EE', '#DDA0DD',
      '#FFD700', '#FFA500', '#FF8C00', '#FF7F50', '#CD5C5C',
      '#F08080', '#FFA07A', '#98D8C8', '#80B080', '#90EE90'
    ];
    return colors[Math.floor(Math.random() * colors.length)];
  }



  // ✅ LOGOUT
  logOut(): void {
    // Clear timer
    if (this.loginTime) {
      const logoutTime = new Date();
      const sessionDuration = logoutTime.getTime() - this.loginTime.getTime();

      // Add session duration to total
      this.totalLoginDurationMs += sessionDuration;

      // Save to localStorage
      localStorage.setItem('totalLoginDuration', this.totalLoginDurationMs.toString());

      this.loginTime = null;
    }
    // Clear session/local storage
    localStorage.removeItem('token');
    sessionStorage.removeItem('authToken');

    // Optional: clear all storage if you want
    localStorage.clear();
    sessionStorage.clear();
    this.router.navigate(['/login']);
    //this.msalService.logoutRedirect();


  }



  getFormattedLoginTime(): string {
    if (!this.loginTime) return '';
    return this.loginTime.toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  ngOnDestroy() {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }


  //

  showNotificationPanel = false;
  notifications: any[] = [];





  // Format date for display
  getFormattedDate(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const diffTime = Math.abs(now.getTime() - date.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays === 1) {
      return 'Today';
    } else if (diffDays === 2) {
      return 'Yesterday';
    } else if (diffDays <= 7) {
      return `${diffDays - 1} days ago`;
    } else {
      return date.toLocaleDateString();
    }
  }




  logout(): void {
    // Clear any auth tokens or user data
    localStorage.removeItem('authToken'); // if you use tokens
    sessionStorage.clear();

    // Redirect to login page
    this.router.navigate(['/login']);
  }


}