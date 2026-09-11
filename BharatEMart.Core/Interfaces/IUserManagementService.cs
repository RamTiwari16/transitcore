using PortalService.Core.Models;
using System;
using System.Collections.Generic;
using System.Text;

namespace PortalService.Core.Interfaces
{
    public interface IUserManagementService
    {
        Task<List<OtcExtensionUser>> GetAllAsync();
        
        public  Task<List<OtcExtensionUser>> GetByBranchAndDesignationAsync(
         int? branchId,
         string? designationName,string? workingDegination
        );
        Task<OtcExtensionUser> GetByIdAsync(int userId);
        public  Task<(int UserId, string WorkingDegination)> InsertAsync(InsertOtcUserRequest request);
        Task<bool> UpdateAsync(UpdateOtcUserRequest request);
        Task<List<OtcErpEmployee>> GetActiveAssistantManagersAsync(EmployeeDto employee);

    }
}
