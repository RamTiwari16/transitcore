using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using PortalService.Core.Models;

namespace PortalService.Core.Interfaces
{
    public interface IMasterService
    {
        Task<List<RegionDto>> GetAllRegionsAsync();
        Task<List<BranchDto>> GetBranchesByRegionAsync(string region);

        Task<List<BranchDto>> GetAllBranchesAsync();
        Task<List<DesignationDto>> GetAllDesignationAsync();
        public  Task<List<WorkingDesignationDto>> GetAllWorkingDesignationAsync();





    }
}
