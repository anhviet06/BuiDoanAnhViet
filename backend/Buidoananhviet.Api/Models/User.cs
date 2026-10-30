namespace Buidoananhviet.Api.Models;

public static class Roles
{
    public const string Admin = "admin";
    public const string Employee = "employee";
}

public class User
{
    public int Id { get; set; }
    public string Email { get; set; } = "";
    public string Username { get; set; } = "";
    [System.Text.Json.Serialization.JsonIgnore]
    public string PasswordHash { get; set; } = "";
    public string FullName { get; set; } = "";
    public string Role { get; set; } = Roles.Employee;
    public decimal HourlyRate { get; set; }      // Lương theo giờ
    public bool IsLocked { get; set; }            // Khóa/mở tài khoản
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Hồ sơ cá nhân (người dùng tự cập nhật, tùy chọn)
    public string? Phone { get; set; }            // SĐT Việt Nam, dạng 0xxxxxxxxx
    public DateTime? DateOfBirth { get; set; }    // chỉ lấy phần ngày
    public string? Address { get; set; }          // <= 200 ký tự

    // OTP đăng nhập bước 2 (chỉ lưu hash, không trả ra JSON)
    [System.Text.Json.Serialization.JsonIgnore]
    public string? OtpHash { get; set; }
    [System.Text.Json.Serialization.JsonIgnore]
    public DateTime? OtpExpiresAt { get; set; }
    [System.Text.Json.Serialization.JsonIgnore]
    public int OtpFailedCount { get; set; }
}
