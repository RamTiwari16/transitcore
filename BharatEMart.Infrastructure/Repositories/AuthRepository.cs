using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using PortalService.Core.Interfaces;
using PortalService.Core.Jwt;
using PortalService.Core.Models;
using PortalService.Infrastructure.ADO;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace PortalService.Infrastructure.Repositories
{
    public class AuthRepository : IAuthService
    {
        private readonly DbContext _dbContext;
        private readonly IConfiguration _configuration;

        public AuthRepository(DbContext dbContext, IConfiguration config)
        {
            _dbContext = dbContext;
            _configuration = config;
        }


        public async Task<UserDto> Login(LoginDto dto)
        {
            try
            {
                var parameters = new[]
                {
            new SqlParameter("@Email", dto.Email)
        };

                var dt = await _dbContext.ReturnDtWithProcAsync(
                    "SP_LoginByEmail",
                    parameters
                );

                if (dt.Rows.Count == 0)
                    return null;

                var row = dt.Rows[0];

                if (!Convert.ToBoolean(row["IsAuthorized"]))
                    throw new UnauthorizedAccessException(row["Message"].ToString());

                var user = new UserDto
                {
                    Id = Convert.ToInt32(row["Id"]),
                    Email = row["Email"].ToString(),
                    UserName = row["Email"].ToString(),
                    Role = row["Role"].ToString(),
                    Region = row["Region"]?.ToString(),
                    PhoneNo = row["PhoneNo"]?.ToString(),

                    BranchIds = row["BranchIds"] != DBNull.Value
                        ? row["BranchIds"].ToString()
                            .Split(',', StringSplitOptions.RemoveEmptyEntries)
                            .Select(int.Parse)
                            .ToList()
                        : new List<int>()
                };

                var tokenHelper = new JwtTokenHelper(_configuration);
                user.Token = tokenHelper.GenerateToken(user);

                return user;
            }
            catch (UnauthorizedAccessException)
            {
                throw;
            }
            catch (Exception ex)
            {
                throw new Exception("Error while logging in", ex);
            }
        }
        public async Task<UserDto> LoginWithoutSSO(LoginWithoutSSO dto)
        {
            try
            {
                var parameters = new[]
                {
                    new SqlParameter("@EpmCode", dto.EmpCode)
                };

                var dt = await _dbContext.ReturnDtWithProcAsync(
                    "OTC_SP_LoginByEmpcode",
                    parameters
                );

                if (dt.Rows.Count == 0)
                    return null;

                var row = dt.Rows[0];

                if (!Convert.ToBoolean(row["IsAuthorized"]))
                    throw new UnauthorizedAccessException(row["Message"].ToString());

                var user = new UserDto
                {
                    Id = Convert.ToInt32(row["Id"]),
                    Email = row["Email"].ToString(),
                    UserName = row["Email"].ToString(),
                    Role = row["Role"].ToString(),
                    Region = row["Region"]?.ToString(),

                    BranchIds = row["BranchIds"] != DBNull.Value
                        ? row["BranchIds"].ToString()
                            .Split(',', StringSplitOptions.RemoveEmptyEntries)
                            .Select(int.Parse)
                            .ToList()
                        : new List<int>()
                };

                var tokenHelper = new JwtTokenHelper(_configuration);
                user.Token = tokenHelper.GenerateToken(user);

                return user;
            }
            catch (UnauthorizedAccessException)
            {
                throw;
            }
            catch (Exception ex)
            {
                throw new Exception("Error while logging in", ex);
            }
        }



    }
}

