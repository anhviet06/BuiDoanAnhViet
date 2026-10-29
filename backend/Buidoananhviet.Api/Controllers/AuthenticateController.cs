using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Buidoananhviet.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

namespace Buidoananhviet.Api.Controllers;

[Route("api/[controller]")]
[ApiController]
public class AuthenticateController : ControllerBase
{
    private const int MaxOtpFailures = 5;

    private readonly IUserRepository _userRepository;
    private readonly IEmailSender _emailSender;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthenticateController> _logger;

    public AuthenticateController(
        IUserRepository userRepository,
        IEmailSender emailSender,
        IConfiguration configuration,
        ILogger<AuthenticateController> logger)
    {
        _userRepository = userRepository;
        _emailSender = emailSender;
        _configuration = configuration;
        _logger = logger;
    }

    // Đăng ký công khai: luôn gán role employee
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegistrationModel model)
    {
        try
        {
            if (!ModelState.IsValid)
                return BadRequest(new
                {
                    success = false,
                    message = "Dữ liệu không hợp lệ",
                    errors = ModelState.Values.SelectMany(v => v.Errors.Select(e => e.ErrorMessage))
                });

            var email = model.Email.Trim();
            var username = string.IsNullOrWhiteSpace(model.Username)
                ? email.Split('@')[0]
                : model.Username.Trim();

            if (await _userRepository.ExistsAsync(email, username))
                return BadRequest(new { success = false, message = "Email hoặc tên đăng nhập đã tồn tại" });

            var user = new User
            {
                Email = email,
                Username = username,
                FullName = model.FullName.Trim(),
                Role = Roles.Employee,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(model.Password)
            };
            await _userRepository.AddUserAsync(user);

            // Xác thực email: gửi OTP ngay như luồng đăng nhập. Chưa cấp JWT cho tới khi verify-otp.
            // Gửi mail lỗi thì tài khoản vẫn được tạo, app cho bấm "Gửi lại mã" (gọi lại login).
            string? devOtp = null;
            var otpSent = true;
            try
            {
                devOtp = await IssueOtpAsync(user, "Mã OTP xác thực tài khoản TimeGuard");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Gửi OTP sau đăng ký lỗi");
                otpSent = false;
            }

            return Ok(new
            {
                success = true,
                message = otpSent
                    ? "Tạo tài khoản thành công, đã gửi mã OTP tới email"
                    : "Tạo tài khoản thành công nhưng chưa gửi được OTP. Hãy bấm Gửi lại mã.",
                otpRequired = true,
                otpSent,
                devOtp
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Register lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Bước 1: kiểm tra mật khẩu, sinh OTP và gửi email
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginModel model)
    {
        try
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var user = await _userRepository.GetUserByLoginAsync(model.Username);
            if (user == null || !BCrypt.Net.BCrypt.Verify(model.Password, user.PasswordHash))
                return Unauthorized(new { success = false, message = "Sai tên đăng nhập hoặc mật khẩu" });

            if (user.IsLocked)
                return StatusCode(403, new { success = false, message = "Tài khoản đã bị khóa" });

            var devOtp = await IssueOtpAsync(user, "Mã OTP đăng nhập TimeGuard");

            return Ok(new
            {
                success = true,
                message = "Đã gửi mã OTP tới email",
                otpRequired = true,
                devOtp
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Login lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Bước 2: kiểm tra OTP, cấp JWT chứa role
    [HttpPost("verify-otp")]
    public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpModel model)
    {
        try
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var user = await _userRepository.GetUserByLoginAsync(model.Username);
            if (user == null || user.OtpHash == null || user.OtpExpiresAt == null)
                return Unauthorized(new { success = false, message = "OTP không hợp lệ hoặc đã hết hạn" });

            if (user.IsLocked)
                return StatusCode(403, new { success = false, message = "Tài khoản đã bị khóa" });

            if (user.OtpExpiresAt < DateTime.UtcNow || user.OtpFailedCount >= MaxOtpFailures)
            {
                await ClearOtpAsync(user);
                return Unauthorized(new { success = false, message = "OTP đã hết hạn hoặc nhập sai quá nhiều lần, hãy đăng nhập lại" });
            }

            if (!CryptographicOperations.FixedTimeEquals(
                    Encoding.UTF8.GetBytes(user.OtpHash), Encoding.UTF8.GetBytes(HashOtp(model.Otp.Trim()))))
            {
                user.OtpFailedCount++;
                await _userRepository.UpdateUserAsync(user);
                return Unauthorized(new { success = false, message = "OTP không đúng" });
            }

            // OTP dùng một lần
            await ClearOtpAsync(user);

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim(ClaimTypes.Name, user.Username),
                new Claim(ClaimTypes.Email, user.Email),
                new Claim(ClaimTypes.Role, user.Role),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            return Ok(new
            {
                success = true,
                message = "Đăng nhập thành công",
                token = GenerateToken(claims),
                role = user.Role,
                user = new { user.Id, user.Email, user.Username, user.FullName, user.Role }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "VerifyOtp lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    // Thông tin người đang đăng nhập (cần JWT)
    [Authorize]
    [HttpGet("me")]
    public IActionResult Me()
    {
        return Ok(new
        {
            id = User.FindFirstValue(ClaimTypes.NameIdentifier),
            username = User.Identity?.Name,
            email = User.FindFirstValue(ClaimTypes.Email),
            role = User.FindFirstValue(ClaimTypes.Role)
        });
    }

    // Chỉ admin: dùng để kiểm tra phân quyền
    [Authorize(Roles = Roles.Admin)]
    [HttpGet("admin-check")]
    public IActionResult AdminCheck() => Ok(new { success = true, message = "Bạn là admin" });

    // Sinh OTP, lưu hash, rồi gửi email (hoặc in console ở DevMode). Trả OTP thô nếu DevMode, ngược lại null.
    private async Task<string?> IssueOtpAsync(User user, string subject)
    {
        var otp = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
        var expireMinutes = _configuration.GetValue("Otp:ExpireMinutes", 5);
        user.OtpHash = HashOtp(otp);
        user.OtpExpiresAt = DateTime.UtcNow.AddMinutes(expireMinutes);
        user.OtpFailedCount = 0;
        await _userRepository.UpdateUserAsync(user);

        var devMode = _configuration.GetValue<bool>("Otp:DevMode");
        if (devMode)
        {
            // DevMode: in ra console backend và trả kèm trong response để demo
            Console.WriteLine($"[OTP DEV] {user.Email}: {otp}");
            return otp;
        }

        await _emailSender.SendAsync(user.Email, subject,
            $"Mã OTP của bạn là {otp}. Mã có hiệu lực trong {expireMinutes} phút.");
        return null;
    }

    private async Task ClearOtpAsync(User user)
    {
        user.OtpHash = null;
        user.OtpExpiresAt = null;
        user.OtpFailedCount = 0;
        await _userRepository.UpdateUserAsync(user);
    }

    // OTP chỉ 6 số nên dùng HMAC với khóa bí mật của server thay vì lưu thô
    private string HashOtp(string otp)
    {
        var key = Encoding.UTF8.GetBytes(_configuration["Jwt:Key"]!);
        return Convert.ToHexString(HMACSHA256.HashData(key, Encoding.UTF8.GetBytes(otp)));
    }

    private string GenerateToken(IEnumerable<Claim> claims)
    {
        var jwt = _configuration.GetSection("Jwt");
        var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt["Key"]!));

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddMinutes(Convert.ToDouble(jwt["ExpireMinutes"])),
            Issuer = jwt["Issuer"],
            Audience = jwt["Audience"],
            SigningCredentials = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256)
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        return tokenHandler.WriteToken(tokenHandler.CreateToken(tokenDescriptor));
    }
}
