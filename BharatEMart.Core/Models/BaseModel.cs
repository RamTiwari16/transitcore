using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PortalService.Core.Models
{
    public class BaseModel
    {
        public string CreatedBy { get; set; }
        public DateOnly CreatedOn { get; set; }
    }

    public class DateRangeDto
    {
        public DateTime? FromDate { get; set; }
        public DateTime? ToDate { get; set; }
    }

    public class EmployeeDto
    {
        public string EmpId { get; set; }
        public string Company { get; set; }
    }

    public class UserNameDto
    {
       // public int? Id { get; set; }
        public string? Name { get; set; }
        public string? EmployeeId { get; set; }
    }

    public class LoginDto
    {
        public string Email { get; set; }
        public string PassWord { get; set; }
    }
    public class LoginWithoutSSO
    {
        public string EmpCode { get; set; }
    }
    public class DropdownDto
    {
        public int Id { get; set; }
        public string? Name { get; set; }
        public bool? Status { get; set; }
        public string? createDate { get; set; }
    }

    public class RegionDto
    {
        public string Region { get; set; }
    }
    public class BranchDto
    {
        public int BranchId { get; set; }
        public string BranchName { get; set; }
        public string Region { get; set; }
    }
    public class DesignationDto
    {
        public string? DesignationCode { get; set; }
        public string? DesignationName { get; set; }
       
    }
    public class WorkingDesignationDto
    {
      
        public string? WorkingDegination { get; set; }
       
    }
    public class FilterUserDto
    {
        public int? branchId { get; set; }
        public string? designationName { get; set; }
        public string? workingDegination { get; set; }
       
    }





}
