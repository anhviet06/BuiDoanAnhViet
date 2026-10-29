using System.ComponentModel.DataAnnotations;

namespace Buidoananhviet.Api.Models;

public class RegistrationModel
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(6)]
    public string Password { get; set; } = string.Empty;

    [Required]
    public string FullName { get; set; } = string.Empty;

    // Tùy chọn: bỏ trống thì lấy phần trước dấu @ của email
    public string? Username { get; set; }
}

public class LoginModel
{
    // Chấp nhận cả email lẫn username
    [Required]
    public string Username { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}

public class VerifyOtpModel
{
    [Required]
    public string Username { get; set; } = string.Empty;

    [Required]
    public string Otp { get; set; } = string.Empty;
}
