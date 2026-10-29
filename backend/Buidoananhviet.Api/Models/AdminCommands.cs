using System.Text;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Models;

/// <summary>
/// Lệnh quản trị chạy bằng `dotnet run -- <lệnh>` (xử lý TRƯỚC khi mở web host, chỉ ở môi trường Development):
///   --reset-demo               xóa sạch chấm công/nghỉ phép/user (trừ "admin"), đồng bộ 5 ca, nạp dữ liệu mẫu
///   --seed-demo                CHỈ nạp thêm dữ liệu mẫu (không xóa gì); từ chối nếu DB đã có chấm công/nghỉ phép
///   --make-admin &lt;email&gt;       đặt role admin cho user theo email (không phân biệt hoa thường)
///   --make-employee &lt;email&gt;    đặt role employee
/// Đổi role xong phải ĐĂNG XUẤT rồi đăng nhập lại (role nằm trong JWT).
/// </summary>
public static class AdminCommands
{
    public static bool IsCommand(string[] args) =>
        args.Any(a => a is "--reset-demo" or "--seed-demo" or "--make-admin" or "--make-employee");

    public static async Task<int> RunAsync(string[] args, ApplicationDbContext db, IConfiguration cfg, ILogger logger, bool isDevelopment, TextWriter? output = null)
    {
        var o = output ?? Console.Out;
        if (!isDevelopment)
        {
            o.WriteLine("Từ chối: lệnh quản trị chỉ chạy ở môi trường Development (ASPNETCORE_ENVIRONMENT=Development).");
            return 2;
        }

        var seed = Array.IndexOf(args, "--seed-demo");
        if (seed >= 0) return await SeedDemoOnlyAsync(db, cfg, logger, o);
        var reset = Array.IndexOf(args, "--reset-demo");
        var makeAdmin = Array.IndexOf(args, "--make-admin");
        var makeEmp = Array.IndexOf(args, "--make-employee");
        if (reset >= 0) return await ResetDemoAsync(db, cfg, logger, o);
        if (makeAdmin >= 0) return await SetRoleAsync(db, args, makeAdmin, Roles.Admin, o);
        if (makeEmp >= 0) return await SetRoleAsync(db, args, makeEmp, Roles.Employee, o);
        return 1;
    }

    // ===== --make-admin / --make-employee =====
    public static async Task<int> SetRoleAsync(ApplicationDbContext db, string[] args, int index, string role, TextWriter o)
    {
        var email = index + 1 < args.Length ? args[index + 1].Trim() : "";
        if (string.IsNullOrEmpty(email) || email.StartsWith("--"))
        {
            o.WriteLine($"Thiếu email. Cú pháp: dotnet run -- {args[index]} <email>");
            return 1;
        }
        var lower = email.ToLowerInvariant();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == lower);
        if (user == null)
        {
            o.WriteLine($"Không tìm thấy user có email '{email}'.");
            return 3;
        }
        if (user.Role == role)
        {
            o.WriteLine($"{user.Username} ({user.Email}) đã là '{role}', không đổi gì.");
            return 0;
        }
        var before = user.Role;
        user.Role = role;
        await db.SaveChangesAsync();
        o.WriteLine($"Đã đổi role của {user.Username} ({user.Email}): {before} -> {role}.");
        o.WriteLine("Hãy ĐĂNG XUẤT rồi đăng nhập lại trong app để token mới có role mới.");
        return 0;
    }

    // ===== --seed-demo: chỉ thêm, không xóa =====
    public static async Task<int> SeedDemoOnlyAsync(ApplicationDbContext db, IConfiguration cfg, ILogger logger, TextWriter o)
    {
        var att = await db.Attendances.CountAsync();
        var leaves = await db.Leaves.CountAsync();
        if (att > 0 || leaves > 0)
        {
            o.WriteLine($"Từ chối: DB đã có {att} chấm công và {leaves} đơn nghỉ phép. --seed-demo chỉ chạy trên DB chưa có dữ liệu (muốn làm lại từ đầu hãy dùng --reset-demo).");
            return 5;
        }
        if (!await db.Users.AnyAsync(u => u.Role == Roles.Admin))
        {
            o.WriteLine("Dừng: chưa có tài khoản admin nào (cần admin làm người xử lý các bản ghi mẫu).");
            return 4;
        }
        await DbSeeder.EnsureSettingsAsync(db);
        await DbSeeder.SyncShiftsAsync(db, logger, forceDefinition: false);
        var users = await db.Users.CountAsync();
        var r = await DemoSeeder.SeedAsync(db, cfg, logger);
        o.WriteLine($"Đã nạp dữ liệu mẫu: +{r.Employees} nhân viên (tổng user {users} -> {await db.Users.CountAsync()}), {r.Attendances} lượt chấm công, {r.Leaves} đơn nghỉ phép.");
        foreach (var w in r.Warnings) o.WriteLine("CẢNH BÁO: " + w);
        foreach (var e in await db.Users.Where(u => u.Role == Roles.Employee).OrderBy(u => u.Id).ToListAsync())
            o.WriteLine($"  {e.Username,-10} <{e.Email}>");
        return 0;
    }

    // ===== --reset-demo =====
    public static async Task<int> ResetDemoAsync(ApplicationDbContext db, IConfiguration cfg, ILogger logger, TextWriter o)
    {
        var keep = await db.Users.FirstOrDefaultAsync(u => u.Username.ToLower() == "admin");
        if (keep == null)
        {
            o.WriteLine("Dừng: không có user 'admin' để giữ lại. Không xóa gì cả.");
            return 4;
        }

        var before = await CountsAsync(db);
        var toDelete = await db.Users.Where(u => u.Id != keep.Id).OrderBy(u => u.Id).Select(u => u.Username + " <" + u.Email + ">").ToListAsync();
        o.WriteLine("=== RESET DỮ LIỆU (phá hủy) ===");
        o.WriteLine($"Sẽ XÓA: {before.attendances} chấm công, {before.leaves} đơn nghỉ phép, {toDelete.Count} user.");
        o.WriteLine($"GIỮ: user '{keep.Username}' <{keep.Email}> (role {keep.Role}), cấu hình công ty, 5 ca cố định + mã QR.");
        foreach (var u in toDelete) o.WriteLine($"  - xóa user: {u}");

        // Thứ tự theo khóa ngoại: Attendances -> Leaves -> Users
        await db.Attendances.ExecuteDeleteAsync();
        await db.Leaves.ExecuteDeleteAsync();
        await db.Users.Where(u => u.Id != keep.Id).ExecuteDeleteAsync();
        db.ChangeTracker.Clear();

        await DbSeeder.EnsureSettingsAsync(db);
        await DbSeeder.SyncShiftsAsync(db, logger, forceDefinition: true);
        var result = await DemoSeeder.SeedAsync(db, cfg, logger);

        var after = await CountsAsync(db);
        o.WriteLine("");
        o.WriteLine("=== TÓM TẮT (trước -> sau) ===");
        o.WriteLine($"Users:       {before.users} -> {after.users}");
        o.WriteLine($"Shifts:      {before.shifts} -> {after.shifts}");
        o.WriteLine($"Attendances: {before.attendances} -> {after.attendances}");
        o.WriteLine($"Leaves:      {before.leaves} -> {after.leaves}");
        foreach (var w in result.Warnings) o.WriteLine("CẢNH BÁO: " + w);

        o.WriteLine("");
        o.WriteLine("=== 5 CA CỐ ĐỊNH ===");
        foreach (var s in await db.Shifts.OrderBy(s => s.Id).ToListAsync())
            o.WriteLine($"  [{s.Id}] {s.Name,-14} {ShiftTime.Format(s.StartTime)} - {ShiftTime.Format(s.EndTime)}  QR: {s.QrToken}");

        o.WriteLine("");
        o.WriteLine("=== TỪNG NHÂN VIÊN ===");
        o.WriteLine(new StringBuilder().Append($"{"username",-10}{"ngày công",10}{"giờ",9}{"phạt (đ)",12}{"lương (đ)",13}{"nghi ngờ",10}{"đang mở",9}{"đơn nghỉ",10}").ToString());
        var employees = await db.Users.Where(u => u.Role == Roles.Employee).OrderBy(u => u.Id).ToListAsync();
        foreach (var e in employees)
        {
            var mine = await db.Attendances.Where(a => a.UserId == e.Id).ToListAsync();
            var done = mine.Where(a => a.CheckOutAt != null).ToList();
            var leaves = await db.Leaves.CountAsync(l => l.UserId == e.Id);
            o.WriteLine($"{e.Username,-10}{done.Select(a => a.WorkDate.Date).Distinct().Count(),10}{done.Sum(a => a.WorkedHours),9:0.00}{done.Sum(a => a.LatePenalty),12:N0}{done.Sum(a => a.Pay),13:N0}" +
                        $"{mine.Count(a => a.Status == AttendanceStatus.Suspicious),10}{mine.Count(a => a.CheckOutAt == null),9}{leaves,10}   <{e.Email}>");
        }
        o.WriteLine("");
        o.WriteLine($"Mật khẩu nhân viên = Seed:EmployeePassword (appsettings.Development.json). Admin giữ nguyên mật khẩu cũ.");
        return 0;
    }

    private static async Task<(int users, int shifts, int attendances, int leaves)> CountsAsync(ApplicationDbContext db) =>
        (await db.Users.CountAsync(), await db.Shifts.CountAsync(), await db.Attendances.CountAsync(), await db.Leaves.CountAsync());
}
