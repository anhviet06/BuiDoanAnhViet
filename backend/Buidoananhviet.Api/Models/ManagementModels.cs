using System.ComponentModel.DataAnnotations;

namespace Buidoananhviet.Api.Models;

// Admin tạo nhân viên (admin nhập mật khẩu ban đầu)
public class UserCreateModel
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(3)]
    public string Username { get; set; } = string.Empty;

    [Required, MinLength(6)]
    public string Password { get; set; } = string.Empty;

    [Required]
    public string FullName { get; set; } = string.Empty;

    [Range(0, 100_000_000)]
    public decimal HourlyRate { get; set; }

    // "employee" (mặc định) hoặc "admin"
    public string Role { get; set; } = Roles.Employee;
}

// Admin sửa nhân viên (không đổi mật khẩu ở đây)
public class UserUpdateModel
{
    [Required, EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(3)]
    public string Username { get; set; } = string.Empty;

    [Required]
    public string FullName { get; set; } = string.Empty;

    [Range(0, 100_000_000)]
    public decimal HourlyRate { get; set; }

    public string Role { get; set; } = Roles.Employee;
}

public class LockUserModel
{
    public bool IsLocked { get; set; }
}

public class ResetPasswordModel
{
    [Required, MinLength(6)]
    public string NewPassword { get; set; } = string.Empty;
}

public class ChangePasswordModel
{
    [Required]
    public string CurrentPassword { get; set; } = string.Empty;

    [Required, MinLength(6)]
    public string NewPassword { get; set; } = string.Empty;
}

// Người dùng tự sửa hồ sơ của mình. Mọi trường đều tùy chọn: không gửi = giữ nguyên, chuỗi rỗng = xóa
// (riêng họ tên không được xóa). Kiểm tra hợp lệ ở ProfileRules.
public class ProfileUpdateModel
{
    public string? FullName { get; set; }

    public string? Phone { get; set; }

    // "yyyy-MM-dd"
    public string? DateOfBirth { get; set; }

    public string? Address { get; set; }
}

public class ShiftModel
{
    [Required]
    public string Name { get; set; } = string.Empty;

    // Định dạng "HH:mm" hoặc "HH:mm:ss"; giờ kết thúc nhận thêm "24:00" (hết ngày)
    [Required]
    [System.Text.Json.Serialization.JsonConverter(typeof(ShiftTimeJsonConverter))]
    public TimeSpan StartTime { get; set; }

    [Required]
    [System.Text.Json.Serialization.JsonConverter(typeof(ShiftTimeJsonConverter))]
    public TimeSpan EndTime { get; set; }

    [Range(0, 240)]
    public int LateGraceMinutes { get; set; } = 5;

    public bool IsActive { get; set; } = true;
}

// Vị trí công ty + bán kính + mức phạt đi trễ
public class CompanySettingsModel
{
    [Range(-90, 90)]
    public double Latitude { get; set; }

    [Range(-180, 180)]
    public double Longitude { get; set; }

    [Range(1, 100_000)]
    public double RadiusMeters { get; set; }

    [Range(0, 100_000_000)]
    public decimal LatePenaltyPerMinute { get; set; }
}

public class LeaveRequestModel
{
    [Required]
    public DateTime FromDate { get; set; }

    [Required]
    public DateTime ToDate { get; set; }

    [Required]
    public string Reason { get; set; } = string.Empty;
}

public class LeaveDecisionModel
{
    public string? AdminNote { get; set; }
}
