using PortalService.Core.Models;
using System;
using System.Collections.Generic;
using System.Text;

namespace PortalService.Core.Interfaces
{
    public interface IAuthService
    {
        Task<UserDto> Login(LoginDto model);
        Task<UserDto> LoginWithoutSSO(LoginWithoutSSO model);
    }
}
