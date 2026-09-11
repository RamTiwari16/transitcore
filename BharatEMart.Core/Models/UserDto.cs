using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace PortalService.Core.Models
{
    public  class UserDto : BaseModel
    {
        public int Id { get; set; }
        public string? Email { get; set; }
        public string? UserName { get; set; }
        public string? UserRegNo { get; set; }
       
        public string? Role { get; set; }
        public string? Branch { get; set; }
        public string? Region { get; set; }
        public string? PhoneNo { get; set; }
        public List<int> BranchIds { get; set; } = new();
        public string? RoleName { get; set; }
        public string? Token { get; set; }
     
    }

    public class UserDetailsDto
    {
        public int UserId { get; set; }
        public string? Email { get; set; }
        public string? UserName { get; set; }
        public string? MobileNo { get; set; }
        public string? UserRegNo { get; set; }
 
        public string? Branch_Name { get; set; }
        public string? RoleName { get; set; }
        public string? RegionName { get; set; }
        public string? Branch_Id { get; set; }
        public string? LastLogin { get; set; }


       

    }







}
