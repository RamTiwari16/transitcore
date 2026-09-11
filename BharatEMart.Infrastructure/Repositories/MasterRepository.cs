
using IDP.Api.Encription;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.Data.SqlClient;
using Microsoft.VisualBasic;
using PortalService.Core.Interfaces;
using PortalService.Core.Models;
using PortalService.Infrastructure.ADO;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Reflection.PortableExecutable;
using System.Text;
using System.Threading.Tasks;

namespace PortalService.Infrastructure.Repositories
{
    public class MasterRepository : IMasterService
    {
        private readonly DbContext _dbContext;
        public MasterRepository(DbContext dbContext)
        {
            _dbContext = dbContext;

        }

        public async Task<List<BranchDto>> GetAllBranchesAsync()
        {

            var dt = await _dbContext.ReturnDtWithProcAsync(
                "OTC_SP_GetBranches"
                
            );

            var branches = new List<BranchDto>();

            foreach (DataRow row in dt.Rows)
            {
                branches.Add(new BranchDto
                {
                    BranchId = Convert.ToInt32(row["BranchId"]),
                    BranchName = row["BranchName"]?.ToString(),
                    Region = row["Region"]?.ToString()
                });
            }

            return branches;
        }

        public async Task<List<DesignationDto>> GetAllDesignationAsync()
        {
            var dt = await _dbContext.ReturnDtWithProcAsync(
                 "SP_OTC_Get_Designations"

             );

            var Designation = new List<DesignationDto>();

            foreach (DataRow row in dt.Rows)
            {
                Designation.Add(new DesignationDto
                {
               
                   // DesignationCode = row["DesignationCode"]?.ToString(),
                    DesignationName = row["DesignationName"]?.ToString()
                });
            }

            return Designation;
        }
        public async Task<List<WorkingDesignationDto>> GetAllWorkingDesignationAsync()
        {
            var dt = await _dbContext.ReturnDtWithProcAsync(
                 "SP_OTC_Extension_WorkingDesignation"

             );

            var Designation = new List<WorkingDesignationDto>();

            foreach (DataRow row in dt.Rows)
            {
                Designation.Add(new WorkingDesignationDto
                {

                    // DesignationCode = row["DesignationCode"]?.ToString(),
                    WorkingDegination = row["WorkingDegination"]?.ToString()
                });
            }

            return Designation;
        }

        // 1️⃣ Get Regions
        public async Task<List<RegionDto>> GetAllRegionsAsync()
        {
            var dt = await _dbContext.ReturnDtWithProcAsync(
                "OTC_SP_GetDistinctRegions"
            );

            var regions = new List<RegionDto>();

            foreach (DataRow row in dt.Rows)
            {
                regions.Add(new RegionDto
                {
                    Region = row["Region"]?.ToString()
                });
            }

            return regions;
        }

        // 2️⃣ Get Branches By Region ONLY
        public async Task<List<BranchDto>> GetBranchesByRegionAsync(string region)
        {
            var parameters = new[]
            {
            new SqlParameter("@Region", region)
        };

            var dt = await _dbContext.ReturnDtWithProcAsync(
                "OTC_SP_GetBranchesByRegion",
                parameters
            );

            var branches = new List<BranchDto>();

            foreach (DataRow row in dt.Rows)
            {
                branches.Add(new BranchDto
                {
                    BranchId = Convert.ToInt32(row["BranchId"]),
                    BranchName = row["BranchName"]?.ToString(),
                    Region = row["Region"]?.ToString()
                });
            }

            return branches;
        }






    }
}
