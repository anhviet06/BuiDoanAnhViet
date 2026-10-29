using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Models;

/// <summary>
/// Seed lúc khởi động: CHỈ đảm bảo cấu hình công ty + 5 ca cố định (QR cố định). KHÔNG tạo/đồng bộ user
/// (kể cả admin; admin bị xóa cũng không tự sinh lại). Dữ liệu mẫu chỉ nạp bằng `dotnet run -- --reset-demo`.
/// </summary>
public static class DbSeeder
{
    // Tiền tố tên ca rác do test tạo ra: xóa nếu chưa có chấm công, có rồi thì giữ và báo lại
    private static readonly string[] JunkShiftPrefixes = { "Ca ET", "Ca RP", "Ca UI test", "Ca ZZ", "Ca Test", "Ca test" };

    public static async Task SeedAsync(ApplicationDbContext db, IConfiguration cfg, ILogger logger)
    {
        await EnsureSettingsAsync(db);
        await SyncShiftsAsync(db, logger, forceDefinition: false);
    }

    public static async Task EnsureSettingsAsync(ApplicationDbContext db)
    {
        if (!await db.Settings.AnyAsync())
        {
            db.Settings.AddRange(
                new Setting { Key = SettingKeys.CompanyLat, Value = "10.7769" },
                new Setting { Key = SettingKeys.CompanyLng, Value = "106.7009" },
                new Setting { Key = SettingKeys.RadiusMeters, Value = "100" },
                new Setting { Key = SettingKeys.LatePenaltyPerMinute, Value = "1000" });
            await db.SaveChangesAsync();
        }
    }

    /// <summary>
    /// Đồng bộ đúng 5 ca cố định theo TÊN (idempotent): đổi tên 2 ca seed cũ (Ca sáng/Ca chiều -> Ca 1/Ca 2, giữ Id),
    /// thêm ca còn thiếu, ép qrToken về giá trị cố định, dọn ca rác của test (nếu chưa có chấm công).
    /// [forceDefinition] = true (dùng ở --reset-demo) thì ép cả giờ + isActive; false thì chỉ ép tên/token và
    /// giữ giờ/trạng thái mà admin đã chỉnh.
    /// </summary>
    public static async Task SyncShiftsAsync(ApplicationDbContext db, ILogger logger, bool forceDefinition)
    {
        var shifts = await db.Shifts.ToListAsync();

        // 1) Đổi tên 2 ca seed cũ (giữ Id, giữ dữ liệu chấm công cũ)
        Rename(shifts, "Ca sáng", FixedShifts.Ca1, FixedShifts.Get(FixedShifts.Ca1), db);
        Rename(shifts, "Ca chiều", FixedShifts.Ca2, FixedShifts.Get(FixedShifts.Ca2), db);

        // 2) Giải phóng token cố định nếu ca khác đang giữ (unique index) trước khi gán
        var fixedTokens = FixedShifts.All.Select(f => f.QrToken).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var fixedNames = FixedShifts.All.Select(f => f.Name).ToHashSet();
        foreach (var other in shifts.Where(s => !fixedNames.Contains(s.Name) && fixedTokens.Contains(s.QrToken)))
            other.QrToken = Guid.NewGuid().ToString("N");
        await db.SaveChangesAsync();

        // 3) Thêm ca thiếu / ép token (và định nghĩa khi force)
        foreach (var f in FixedShifts.All)
        {
            var s = shifts.FirstOrDefault(x => x.Name == f.Name);
            if (s == null)
            {
                s = new Shift { Name = f.Name, StartTime = f.Start, EndTime = f.End, QrToken = f.QrToken, IsActive = true };
                db.Shifts.Add(s);
                shifts.Add(s);
            }
            else
            {
                s.QrToken = f.QrToken;
                if (forceDefinition)
                {
                    s.StartTime = f.Start;
                    s.EndTime = f.End;
                    s.IsActive = true;
                }
            }
        }
        await db.SaveChangesAsync();

        // 4) Dọn ca rác do test tạo
        foreach (var junk in shifts.Where(s => !fixedNames.Contains(s.Name) && JunkShiftPrefixes.Any(p => s.Name.StartsWith(p, StringComparison.OrdinalIgnoreCase))).ToList())
        {
            if (await db.Attendances.AnyAsync(a => a.ShiftId == junk.Id))
            {
                logger.LogWarning("Giữ ca '{Name}' (Id {Id}) vì đã có dữ liệu chấm công.", junk.Name, junk.Id);
                continue;
            }
            db.Shifts.Remove(junk);
            logger.LogInformation("Đã xóa ca rác '{Name}' (Id {Id}).", junk.Name, junk.Id);
        }
        await db.SaveChangesAsync();
    }

    private static void Rename(List<Shift> shifts, string oldName, string newName, FixedShift def, ApplicationDbContext db)
    {
        if (shifts.Any(s => s.Name == newName)) return;
        var old = shifts.FirstOrDefault(s => s.Name == oldName);
        if (old == null) return;
        old.Name = newName;
        old.StartTime = def.Start;
        old.EndTime = def.End;
        old.IsActive = true;
    }
}
