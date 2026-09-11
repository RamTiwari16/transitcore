using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using PortalService.Core.Interfaces;
using PortalService.Core.Models;
using PortalService.Infrastructure.Repositories;
using System.Reflection;

namespace OTCExtenssionUser.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authRepository;

        public AuthController(IAuthService authRepository)
        {
            _authRepository = authRepository;
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginDto request)
        {
            try
            {
                if (request == null)
                {
                    return BadRequest(
                        new ApiResponseDto<string>
                        {
                            Success = false,
                            Message = "Request is required"
                        }
                    );
                }

                if (string.IsNullOrWhiteSpace(request.Email))
                {
                    return BadRequest(
                        new ApiResponseDto<string>
                        {
                            Success = false,
                            Message = "Email is required"
                        }
                    );
                }

                var response = await _authRepository.Login(request);

                if (response == null)
                {
                    return Unauthorized(
                        new ApiResponseDto<string>
                        {
                            Success = false,
                            Message = "Invalid user"
                        }
                    );
                }

                return Ok(
                    new ApiResponseDto<UserDto>
                    {
                        Success = true,
                        Message = "Login successful",
                        Data = response
                    }
                );
            }
            catch (UnauthorizedAccessException ex)
            {
                return Unauthorized(
                    new ApiResponseDto<string>
                    {
                        Success = false,
                        Message = ex.Message
                    }
                );
            }
            catch (Exception ex)
            {
                return StatusCode(
                    500,
                    new ApiResponseDto<string>
                    {
                        Success = false,
                        Message = ex.Message
                    }
                );
            }
        }






    }

       
}
