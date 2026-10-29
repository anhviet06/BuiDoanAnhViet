using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Buidoananhviet.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Buidoananhviet.Api.Controllers;

// Đã đăng nhập mới dùng được; các thao tác quản lý nhân viên chỉ admin.
[Authorize]
[Route("api/[controller]")]
[ApiController]
public class UsersController : ControllerBase
{
    private readonly IUserRepository _userRepository;
    private readonly IAttendanceRepository _attendanceRepository;
    private readonly ILogger<UsersController> _logger;

    public UsersController(
        IUserRepository userRepository,
        IAttendanceRepository attendanceRepository,
        ILogger<UsersController> logger)
    {
        _userRepository = userRepository;
        _attendanceRepository = attendanceRepository;
        _logger = logger;
    }

    private IActionResult Fail(int status, string message) =>
        StatusCode(status, new { success = false, message });

    private static bool ValidRole(string role) => role == Roles.Admin || role == Roles.Employee;

    [Authorize(Roles = Roles.Admin)]
    [HttpGet]
    public async Task<IActionResult> GetUsers()
    {
        try
        {
            return Ok(await _userRepository.GetUsersAsync());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetUsers lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Admin)]
    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetUserById(int id)
    {
        try
        {
            var user = await _userRepository.GetUserByIdAsync(id);
            if (user == null)
                return NotFound();
            return Ok(user);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetUserById lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Admin)]
    [HttpPost]
    public async Task<IActionResult> AddUser([FromBody] UserCreateModel model)
    {
        try
        {
            if (!ValidRole(model.Role))
                return BadRequest(new { success = false, message = "Role phải là admin hoặc employee" });
            if (await _userRepository.ExistsAsync(model.Email, model.Username))
                return BadRequest(new { success = false, message = "Email hoặc tên đăng nhập đã tồn tại" });

            var user = new User
            {
                Email = model.Email.Trim(),
                Username = model.Username.Trim(),
                FullName = model.FullName.Trim(),
                HourlyRate = model.HourlyRate,
                Role = model.Role,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(model.Password)
            };
            await _userRepository.AddUserAsync(user);
            return CreatedAtAction(nameof(GetUserById), new { id = user.Id }, user);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AddUser lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Admin)]
    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateUser(int id, [FromBody] UserUpdateModel model)
    {
        try
        {
            var user = await _userRepository.GetUserByIdAsync(id);
            if (user == null)
                return NotFound();
            if (!ValidRole(model.Role))
                return BadRequest(new { success = false, message = "Role phải là admin hoặc employee" });
            if (id == User.GetUserId() && model.Role != user.Role)
                return BadRequest(new { success = false, message = "Không thể tự đổi role của chính mình" });
            if (await _userRepository.ExistsAsync(model.Email, model.Username, id))
                return BadRequest(new { success = false, message = "Email hoặc tên đăng nhập đã tồn tại" });

            user.Email = model.Email.Trim();
            user.Username = model.Username.Trim();
            user.FullName = model.FullName.Trim();
            user.HourlyRate = model.HourlyRate;
            user.Role = model.Role;
            await _userRepository.UpdateUserAsync(user);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "UpdateUser lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Khóa/mở tài khoản
    [Authorize(Roles = Roles.Admin)]
    [HttpPut("{id:int}/lock")]
    public async Task<IActionResult> LockUser(int id, [FromBody] LockUserModel model)
    {
        try
        {
            var user = await _userRepository.GetUserByIdAsync(id);
            if (user == null)
                return NotFound();
            if (id == User.GetUserId() && model.IsLocked)
                return BadRequest(new { success = false, message = "Không thể tự khóa chính mình" });

            user.IsLocked = model.IsLocked;
            await _userRepository.UpdateUserAsync(user);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "LockUser lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Admin đặt lại mật khẩu cho nhân viên
    [Authorize(Roles = Roles.Admin)]
    [HttpPut("{id:int}/password")]
    public async Task<IActionResult> ResetPassword(int id, [FromBody] ResetPasswordModel model)
    {
        try
        {
            var user = await _userRepository.GetUserByIdAsync(id);
            if (user == null)
                return NotFound();

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(model.NewPassword);
            await _userRepository.UpdateUserAsync(user);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "ResetPassword lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Xóa cứng chỉ khi chưa có chấm công; đã có thì phải dùng khóa (409)
    [Authorize(Roles = Roles.Admin)]
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        try
        {
            var user = await _userRepository.GetUserByIdAsync(id);
            if (user == null)
                return NotFound();
            if (id == User.GetUserId())
                return BadRequest(new { success = false, message = "Không thể tự xóa chính mình" });
            if (await _attendanceRepository.HasAttendanceForUserAsync(id))
                return Conflict(new { success = false, message = "Nhân viên đã có dữ liệu chấm công, không thể xóa. Hãy khóa tài khoản." });

            await _userRepository.DeleteUserAsync(id);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "DeleteUser lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // ===== Hồ sơ của chính mình (mọi role) =====

    [HttpGet("me")]
    public async Task<IActionResult> GetMe()
    {
        try
        {
            var user = await _userRepository.GetUserByIdAsync(User.GetUserId());
            if (user == null)
                return NotFound();
            return Ok(user);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetMe lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [HttpPut("me")]
    public async Task<IActionResult> UpdateMe([FromBody] ProfileUpdateModel model)
    {
        try
        {
            var user = await _userRepository.GetUserByIdAsync(User.GetUserId());
            if (user == null)
                return NotFound();

            user.FullName = model.FullName.Trim();
            await _userRepository.UpdateUserAsync(user);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "UpdateMe lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Nhân viên tự đổi mật khẩu
    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordModel model)
    {
        try
        {
            var user = await _userRepository.GetUserByIdAsync(User.GetUserId());
            if (user == null)
                return NotFound();
            if (!BCrypt.Net.BCrypt.Verify(model.CurrentPassword, user.PasswordHash))
                return BadRequest(new { success = false, message = "Mật khẩu hiện tại không đúng" });

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(model.NewPassword);
            await _userRepository.UpdateUserAsync(user);
            return Ok(new { success = true, message = "Đổi mật khẩu thành công" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "ChangePassword lỗi");
            return StatusCode(500, "Internal server error");
        }
    }
}
