using System.Security.Cryptography;
using System.Text;
using Buidoananhviet.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Services;

/// <summary>
/// Đăng nhập bằng thiết bị tin cậy (dùng cho "đăng nhập bằng khuôn mặt"): sau khi người dùng đăng nhập bằng mật khẩu + OTP
/// và bật tính năng, app xin một token riêng của thiết bị. Server chỉ lưu BĂM (SHA-256) của token.
/// Lưu ý trung thực: server KHÔNG nhận diện được khuôn mặt; bước khuôn mặt chỉ là xác nhận người sống trên thiết bị đã đăng ký
/// bằng OTP. Độ an toàn dựa vào token theo thiết bị (30 ngày, thu hồi được).
/// </summary>
public interface IDeviceLoginService
{
    /// <summary>Cấp token mới cho (user, thiết bị); token cũ của thiết bị này bị thu hồi. Trả token THÔ (chỉ một lần).</summary>
    Task<(string Token, DateTime ExpiresAt)> IssueAsync(int userId, string deviceId);

    /// <summary>Kiểm tra token; trả user nếu hợp lệ (chưa hết hạn, chưa thu hồi, đúng thiết bị, tài khoản không bị khóa).</summary>
    Task<User?> ValidateAsync(string deviceId, string deviceToken);

    /// <summary>Thu hồi một token (người giữ token tự thu hồi). Trả true nếu có token bị thu hồi.</summary>
    Task<bool> RevokeAsync(string deviceId, string deviceToken);

    /// <summary>Thu hồi mọi token của một người dùng (đổi mật khẩu, admin khóa/đặt lại mật khẩu).</summary>
    Task RevokeAllAsync(int userId);
}

public class DeviceLoginService : IDeviceLoginService
{
    public static readonly TimeSpan Lifetime = TimeSpan.FromDays(30);

    private readonly ApplicationDbContext _db;
    private readonly ITimeService _time;

    public DeviceLoginService(ApplicationDbContext db, ITimeService time)
    {
        _db = db;
        _time = time;
    }

    public static string Hash(string token) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token))).ToLowerInvariant();

    public async Task<(string Token, DateTime ExpiresAt)> IssueAsync(int userId, string deviceId)
    {
        deviceId = deviceId.Trim();
        var now = _time.UtcNow;

        // Mỗi thiết bị chỉ giữ một token còn hiệu lực
        var old = await _db.DeviceLogins.Where(d => d.UserId == userId && d.DeviceId == deviceId && d.RevokedAt == null).ToListAsync();
        foreach (var o in old) o.RevokedAt = now;

        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var entity = new DeviceLogin { UserId = userId, DeviceId = deviceId, TokenHash = Hash(token), CreatedAt = now, ExpiresAt = now + Lifetime };
        _db.DeviceLogins.Add(entity);
        await _db.SaveChangesAsync();
        return (token, entity.ExpiresAt);
    }

    public async Task<User?> ValidateAsync(string deviceId, string deviceToken)
    {
        var hash = Hash(deviceToken);
        var now = _time.UtcNow;
        var login = await _db.DeviceLogins.Include(d => d.User)
            .FirstOrDefaultAsync(d => d.TokenHash == hash && d.DeviceId == deviceId.Trim() && d.RevokedAt == null && d.ExpiresAt > now);
        if (login?.User == null || login.User.IsLocked) return null;

        login.LastUsedAt = now;
        await _db.SaveChangesAsync();
        return login.User;
    }

    public async Task<bool> RevokeAsync(string deviceId, string deviceToken)
    {
        var hash = Hash(deviceToken);
        var login = await _db.DeviceLogins.FirstOrDefaultAsync(d => d.TokenHash == hash && d.DeviceId == deviceId.Trim() && d.RevokedAt == null);
        if (login == null) return false;
        login.RevokedAt = _time.UtcNow;
        await _db.SaveChangesAsync();
        return true;
    }

    public async Task RevokeAllAsync(int userId)
    {
        var now = _time.UtcNow;
        var all = await _db.DeviceLogins.Where(d => d.UserId == userId && d.RevokedAt == null).ToListAsync();
        foreach (var d in all) d.RevokedAt = now;
        if (all.Count > 0) await _db.SaveChangesAsync();
    }
}
