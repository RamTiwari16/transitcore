using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using PortalService.Core.Interfaces;
using PortalService.Core.Models;
using PortalService.Infrastructure.ADO;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace PortalService.Infrastructure.Repositories
{
    public class UserManagementRepository : IUserManagementService
    {
        private readonly DbContext _dbContext;

        public UserManagementRepository(DbContext configuration)
        {
            _dbContext = configuration;
        }
        //public async Task<List<OtcExtensionUser>> GetAllAsync()
        //{
        //    var dt = await _dbContext.ReturnDtWithProcAsync("OTC_SP_GetAllUsers");

        //    var users = new List<OtcExtensionUser>();

        //    foreach (DataRow row in dt.Rows)
        //    {
        //        users.Add(new OtcExtensionUser
        //        {
        //            Id = Convert.ToInt32(row["Id"]),
        //            Email = row["Email"].ToString(),
        //            Role = row["Role"].ToString(),
        //            EmpCode = row["EmpCode"].ToString(),
        //            EmpName = row["EmpName"].ToString(),
        //            DeginationCode = row["DesignationCode"].ToString(),
        //            DeginationName = row["DesignationName"].ToString(),
        //            Region = row["Region"].ToString(),
        //            WorkingDegination = row["WorkingDegination"].ToString(),
        //            CreatedOn = Convert.ToDateTime(row["CreatedOn"]),
        //            CreatedBy = Convert.ToInt32(row["CreatedBy"])
        //        });
        //    }

        //    return users;
        //}


        public async Task<List<OtcExtensionUser>> GetByBranchAndDesignationAsync(
            int? branchId,
            string? designationName,
            string? workingDegination
        )
        {
            var parameters = new[]
            {
                new SqlParameter("@BranchId", branchId ?? (object)DBNull.Value),
                new SqlParameter("@DesignationName", designationName ?? (object)DBNull.Value),
                new SqlParameter("@WorkingDegination", workingDegination ?? (object)DBNull.Value)
            };

            var dt = await _dbContext.ReturnDtWithProcAsync(
                "OTC_SP_GetUsers_ByBranch_And_Designation",
                parameters
            );

            var users = new List<OtcExtensionUser>();

            foreach (DataRow row in dt.Rows)
            {
                var user = new OtcExtensionUser
                {
                    Id = Convert.ToInt32(row["Id"]),
                    Email = row["Email"]?.ToString(),
                    Role = row["Role"]?.ToString(),
                    EmpCode = row["EmpCode"]?.ToString(),
                    EmpName = row["EmpName"]?.ToString(),
                    DeginationCode = row["DesignationCode"]?.ToString(),
                    DeginationName = row["DesignationName"]?.ToString(),
                    Region = row["Region"]?.ToString(),
                    WorkingDegination = row["WorkingDegination"]?.ToString(),
                    PunchLocation = string.IsNullOrWhiteSpace(row["PunchLocation"]?.ToString())
    ? null
    : row["PunchLocation"].ToString(),
                    Shift = row["Shift"].ToString(),
                    Company = row["Company"].ToString(),
                    Status = row["Status"]?.ToString(),
                    IsActive = Convert.ToBoolean(row["IsActive"])
                };

                // 🔹 Branch Names
                if (row.Table.Columns.Contains("BranchNames") &&
                    row["BranchNames"] != DBNull.Value)
                {
                    user.BranchNames = row["BranchNames"]
                        .ToString()!
                        .Split(',', StringSplitOptions.RemoveEmptyEntries)
                        .Select(x => x.Trim())
                        .ToList();
                }

                // 🔹 Branch Ids (optional – uncomment if needed)
                /*
                if (row.Table.Columns.Contains("BranchIds") &&
                    row["BranchIds"] != DBNull.Value)
                {
                    user.BranchIds = row["BranchIds"]
                        .ToString()!
                        .Split(',', StringSplitOptions.RemoveEmptyEntries)
                        .Select(int.Parse)
                        .ToList();
                }
                */

                users.Add(user);
            }

            return users;
        }


        public async Task<List<OtcExtensionUser>> GetAllAsync()
        {
            var dt = await _dbContext.ReturnDtWithProcAsync("OTC_SP_GetAllUsers");

            var users = new List<OtcExtensionUser>();

            foreach (DataRow row in dt.Rows)
            {
                var user = new OtcExtensionUser
                {
                    Id = Convert.ToInt32(row["Id"]),
                    Email = row["Email"]?.ToString(),
                    Role = row["Role"]?.ToString(),
                    EmpCode = row["EmpCode"]?.ToString(),
                    EmpName = row["EmpName"]?.ToString(),
                    DeginationCode = row["DesignationCode"]?.ToString(),
                    DeginationName = row["DesignationName"]?.ToString(),
                    Region = row["Region"]?.ToString(),
                    WorkingDegination = row["WorkingDegination"]?.ToString(),
                   /// CreatedOn = Convert.ToDateTime(row["CreatedOn"]),
                  //  CreatedBy = Convert.ToInt32(row["CreatedBy"]),
                    IsActive = Convert.ToBoolean(row["IsActive"])
                };

                // 🔹 Parse Branch IDs
                //if (row["BranchIds"] != DBNull.Value)
                //{
                //    user.BranchIds = row["BranchIds"]
                //        .ToString()
                //        .Split(',', StringSplitOptions.RemoveEmptyEntries)
                //        .Select(int.Parse)
                //        .ToList();
                //}

                // 🔹 Optional: Branch Names
                if (row["BranchNames"] != DBNull.Value)
                {
                    user.BranchNames = row["BranchNames"]
                        .ToString()
                        .Split(',', StringSplitOptions.RemoveEmptyEntries)
                        .Select(x => x.Trim())
                        .ToList();
                }

                users.Add(user);
            }

            return users;
        }



        public async Task<OtcExtensionUser> GetByIdAsync(int userId)
        {
            var parameters = new[]
                    {
                new SqlParameter("@UserId", userId)
            };

            var ds = await _dbContext.ReturnDsWithProcAsync(
                "OTC_SP_GetUserById",
                parameters
            );

            if (ds.Tables[0].Rows.Count == 0)
                return null;

            var userRow = ds.Tables[0].Rows[0];

            var user = new OtcExtensionUser
            {
                Id = Convert.ToInt32(userRow["Id"]),
                Email = userRow["Email"].ToString(),
                Role = userRow["Role"].ToString(),
                EmpCode = userRow["EmpCode"].ToString(),
                EmpName = userRow["EmpName"].ToString(),
                DeginationCode = userRow["DesignationCode"].ToString(),
                DeginationName = userRow["DesignationName"].ToString(),
                Region = userRow["Region"].ToString(),
                WorkingDegination = userRow["WorkingDegination"].ToString(),
                PunchLocation = userRow["PunchLocation"].ToString(),
                Shift = userRow["Shift"].ToString(),
                Company = userRow["Company"].ToString(),
                CreatedOn = Convert.ToDateTime(userRow["CreatedOn"]),
                CreatedBy = Convert.ToInt32(userRow["CreatedBy"]),
                BranchIds = new List<int>()
            };

            foreach (DataRow row in ds.Tables[1].Rows)
            {
                user.BranchIds.Add(Convert.ToInt32(row["BranchId"]));
            }

            return user;
        }


        public async Task<(int UserId, string WorkingDegination)> InsertAsync(InsertOtcUserRequest request)
        {
            try
            {
                var branchTvp = CreateBranchTvp(request.BranchIds);

                var parameters = new[]
                {
            new SqlParameter("@Email", request.Email),
            new SqlParameter("@Role", request.Role),
            new SqlParameter("@EmpCode", request.EmpCode),
            new SqlParameter("@EmpName", request.EmpName),
            new SqlParameter("@DesignationCode", request.DeginationCode),
            new SqlParameter("@DesignationName", request.DeginationName),
            new SqlParameter("@Region", request.Region),
            new SqlParameter("@WorkingDegination", request.WorkingDegination),
                new SqlParameter("@PunchLocation", request.PunchLocation),
                new SqlParameter("@shift", request.Shift),
                new SqlParameter("@Company", request.Company),
            new SqlParameter("@CreatedBy", request.CreatedBy),


            new SqlParameter("@Branches", SqlDbType.Structured)
            {
                TypeName = "dbo.OTC_IntBranch_TVP",
                Value = branchTvp
            }
        };

                DataTable dt = await _dbContext.ReturnDtWithProcAsync(
                    "OTC_SP_InsertUser",
                    parameters
                );

                if (dt.Rows.Count > 0)
                {
                    int userId = Convert.ToInt32(dt.Rows[0]["UserId"]);

                    string workingDegination =
                        dt.Columns.Contains("WorkingDegination") &&
                        dt.Rows[0]["WorkingDegination"] != DBNull.Value
                        ? dt.Rows[0]["WorkingDegination"].ToString()
                        : null;

                    return (userId, workingDegination);
                }

                return (0, null);
            }
            catch (SqlException sqlEx)
            {
                throw new Exception("Database error occurred while inserting OTC user.", sqlEx);
            }
        }





        public async Task<bool> UpdateAsync(UpdateOtcUserRequest request)
        {
            var branchTvp = CreateBranchTvp(request.BranchIds);

            var isUpdatedParam = new SqlParameter("@IsUpdated", SqlDbType.Bit)
            {
                Direction = ParameterDirection.Output
            };

            var parameters = new[]
            {
                new SqlParameter("@UserId", request.UserId),
                new SqlParameter("@Role", request.Role),
                new SqlParameter("@Region", request.Region),
                new SqlParameter("@WorkingDegination", request.WorkingDegination),
                new SqlParameter("@Email", request.Email),
                new SqlParameter("@PunchLocation", request.PunchLocation),
                new SqlParameter("@Shift", request.Shift),

                new SqlParameter("@Branches", SqlDbType.Structured)
                {
                    TypeName = "dbo.OTC_IntBranch_TVP",
                    Value = branchTvp
                },

                isUpdatedParam
            };

            await _dbContext.ExecuteNonQueryWithProcAsync(
                "OTC_SP_UpdateUser",
                parameters
            );

            return Convert.ToBoolean(isUpdatedParam.Value);
        }

        public async Task<List<OtcErpEmployee>> GetActiveAssistantManagersAsync(EmployeeDto employee)
        {
            var parameters = new[]
            {
            new SqlParameter("@EmployeeCode", string.IsNullOrWhiteSpace(employee.EmpId)
                ? DBNull.Value
                : employee.EmpId),
            new SqlParameter("@Company", string.IsNullOrWhiteSpace(employee.Company)
                ? DBNull.Value
                : employee.Company)
        };

            var dt = await _dbContext.ReturnDtWithProcAsync(
                "sp_OTC_GetActiveERPEmployees",
                parameters
            );

            var employees = new List<OtcErpEmployee>();

            foreach (DataRow row in dt.Rows)
            {
                employees.Add(new OtcErpEmployee
                {
                    RecId = Convert.ToInt32(row["Rec_id"]),
                    Company = row["Company"]?.ToString(),
                    EmployeeCode = row["EmployeeCode"]?.ToString(),
                    EmailId = row["EmailId"]?.ToString(),
                    EmployeeName = row["EmployeeName"]?.ToString(),
                    DesignationName = row["DesignationName"]?.ToString(),
                    DesignationCode = row["DesignationCode"]?.ToString(),
                    Status = row["Status"]?.ToString()
                });
            }

            return employees;
        }


        private DataTable CreateBranchTvp(List<int>? branchIds)
        {
            var dt = new DataTable();
            dt.Columns.Add("BranchId", typeof(int));

            if (branchIds != null)
            {
                foreach (var id in branchIds)
                {
                    dt.Rows.Add(id);
                }
            }

            return dt;
        }


    }
}
