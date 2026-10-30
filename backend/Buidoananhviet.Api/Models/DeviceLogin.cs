namespace Buidoananhviet.Api.Models;

/// <summary>Token đăng nhập theo thiết bị (chỉ lưu băm SHA-256). Xem DeviceLoginService.</summary>
public class DeviceLogin
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User? User { get; set; }
    public string DeviceId { get; set; } = "";
    public string TokenHash { get; set; } = "";   // SHA-256 hex (64 ký tự)
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }       // 30 ngày kể từ lúc cấp
    public DateTime? LastUsedAt { get; set; }
    public DateTime? RevokedAt { get; set; }
}
