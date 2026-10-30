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

// Đăng nhập bằng thiết bị tin cậy (khuôn mặt). Xem Services/DeviceLoginService.cs
public class DeviceTokenRequest
{
    [Required, MaxLength(200)]
    public string DeviceId { get; set; } = string.Empty;
}

public class DeviceLoginModel
{
    [Required, MaxLength(200)]
    public string DeviceId { get; set; } = string.Empty;

    [Required, MaxLength(200)]
    public string DeviceToken { get; set; } = string.Empty;

    // App đã cho người dùng qua bước xác nhận người sống (liveness). false -> 400.
    public bool FaceVerified { get; set; }
}

public class DeviceTokenRevokeModel
{
    [Required, MaxLength(200)]
    public string DeviceId { get; set; } = string.Empty;

    [Required, MaxLength(200)]
    public string DeviceToken { get; set; } = string.Empty;
}
