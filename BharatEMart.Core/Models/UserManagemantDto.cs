using System;
using System.Collections.Generic;
using System.Text;

namespace PortalService.Core.Models
{
    internal class UserManagemantDto
    {
    }
    public class OtcExtensionUser
    {
        public int Id { get; set; }
        public string Email { get; set; }
        public string Role { get; set; }

        public string EmpCode { get; set; }
        public string EmpName { get; set; }

        public string DeginationCode { get; set; }
        public string DeginationName { get; set; }

        public string Region { get; set; }
        public string Status { get; set; }
        public string WorkingDegination { get; set; }
        public string PunchLocation { get; set; }
        public string Shift { get; set; }
        public string Company { get; set; }

        public DateTime CreatedOn { get; set; }
        public int CreatedBy { get; set; }
        public bool IsActive { get; set; }

        public List<int> BranchIds { get; set; } = new();
        public List<string> BranchNames { get; set; } = new();

    }
    public class InsertOtcUserRequest
    {
        public string Email { get; set; }
        public string? Role { get; set; }

        public string EmpCode { get; set; }
        public string EmpName { get; set; }

        public string DeginationCode { get; set; }
        public string DeginationName { get; set; }

        public string Region { get; set; }
        public string WorkingDegination { get; set; }
        public string PunchLocation { get; set; }
        public string Shift { get; set; }
        public string? Company { get; set; }

        public int CreatedBy { get; set; }
        public List<int> BranchIds { get; set; }
    }
    public class UpdateOtcUserRequest
    {
        public int UserId { get; set; }
        public string? Role { get; set; }
        public string? Email { get; set; }
        public string Region { get; set; }
        public string WorkingDegination { get; set; }
        public string? PunchLocation { get; set; }
        public string? Shift { get; set; }
        public List<int> BranchIds { get; set; }
    }
    public class OtcUserRequest
    {
     
        public string? Role { get; set; }
       
      
        public List<int>? BranchIds { get; set; }
    }

    public class OtcErpEmployee
    {
        public int RecId { get; set; }
        public string Company { get; set; }
        public string EmployeeCode { get; set; }
        public string EmailId { get; set; }
        public string EmployeeName { get; set; }

        public string DesignationName { get; set; }
        public string DesignationCode { get; set; }
        public string Status { get; set; }
    }




}
