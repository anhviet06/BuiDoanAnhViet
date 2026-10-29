using Buidoananhviet.Api.Repositories;
using Buidoananhviet.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Models;

/// <summary>Đồng hồ giả lập để nạp dữ liệu quá khứ qua đúng AttendanceService (cùng luật, cùng công thức).</summary>
public class SimulatedClock : ITimeService
{
    private readonly TimeSpan _offset;

    public SimulatedClock(TimeSpan offset, DateTime localNow)
    {
        _offset = offset;
        LocalNow = localNow;
    }

    public DateTime LocalNow { get; set; }
    public DateTime UtcNow => DateTime.SpecifyKind(LocalNow - _offset, DateTimeKind.Utc);
    public DateTime ToLocal(DateTime utc) => DateTime.SpecifyKind(utc, DateTimeKind.Utc) + _offset;
    public DateTime ToUtc(DateTime local) => DateTime.SpecifyKind(local - _offset, DateTimeKind.Utc);
}

/// <summary>Kết quả nạp dữ liệu mẫu.</summary>
public class DemoSeedResult
{
    public int Attendances { get; set; }
    public int Leaves { get; set; }
    public int Employees { get; set; }
    public List<string> Warnings { get; } = new();
}

/// <summary>
/// Bộ dữ liệu mẫu: 5 nhân viên, lịch sử từ 14/09/2026 đến hôm nay. Mọi bản ghi chấm công được tạo bằng cách GỌI
/// AttendanceService.CheckIn/CheckOut/Review/Close với đồng hồ giả lập nên giờ làm, phạt, lương, trạng thái và lý do
/// nghi ngờ đúng 100% quy tắc của server (không tự bịa số). Chỉ nạp qua `dotnet run -- --reset-demo`.
/// </summary>
public static class DemoSeeder
{
    private sealed record Person(string FullName, string Username, decimal Rate, string DeviceId);

    private static readonly Person[] People =
    {
        new("Nguyễn Thị Lan Anh", "lananh", 35000, "5d2f6c1e-8a43-4b7e-9c10-1a2b3c4d5e01"),
        new("Trần Minh Quân", "minhquan", 38000, "9e7b3a42-1f65-4d08-b3a9-2b3c4d5e6f02"),
        new("Lê Hoàng Nam", "hoangnam", 42000, "c4a18d73-6e92-4f1b-8d54-3c4d5e6f7a03"),
        new("Phạm Thu Hà", "thuha", 32000, "7b90e5f6-2d31-4a8c-a6e7-4d5e6f7a8b04"),
        new("Võ Quốc Bảo", "quocbao", 30000, "e1f3a2b8-9c47-4e60-b2d1-5e6f7a8b9c05"),
    };

    public static readonly DateTime HistoryStart = new(2026, 9, 14);

    /// <summary>Email nhận OTP thật: phần trước @ của Seed:EmailBase + "+" + username + "@gmail.com".</summary>
    public static string EmailFor(string emailBase, string username)
    {
        var at = emailBase.IndexOf('@');
        if (at <= 0) throw new InvalidOperationException("Seed:EmailBase phải là một địa chỉ email (vd. ten@gmail.com).");
        return $"{emailBase[..at]}+{username}@{emailBase[(at + 1)..]}";
    }

    public static async Task<DemoSeedResult> SeedAsync(ApplicationDbContext db, IConfiguration cfg, ILogger logger, DateTime? nowLocalOverride = null)
    {
        var result = new DemoSeedResult();
        var offset = TimeSpan.FromHours(cfg.GetValue("Time:UtcOffsetHours", 7.0));
        var nowLocal = nowLocalOverride ?? DateTime.UtcNow + offset;
        var today = nowLocal.Date;

        var empPw = cfg["Seed:EmployeePassword"];
        var emailBase = cfg["Seed:EmailBase"];
        if (string.IsNullOrWhiteSpace(empPw)) throw new InvalidOperationException("Thiếu Seed:EmployeePassword.");
        if (string.IsNullOrWhiteSpace(emailBase)) throw new InvalidOperationException("Thiếu Seed:EmailBase (vd. buianhviet06@gmail.com).");

        var admin = await db.Users.Where(u => u.Role == Roles.Admin).OrderBy(u => u.Username == "admin" ? 0 : 1).ThenBy(u => u.Id).FirstOrDefaultAsync()
            ?? throw new InvalidOperationException("Không có tài khoản admin nào trong DB (cần giữ admin để làm người xử lý bản ghi mẫu).");
        var shifts = await db.Shifts.ToDictionaryAsync(s => s.Name);
        foreach (var f in FixedShifts.All)
            if (!shifts.ContainsKey(f.Name)) throw new InvalidOperationException($"Thiếu ca '{f.Name}' (hãy chạy đồng bộ ca trước).");

        // ===== Nhân viên =====
        var users = new Dictionary<string, User>();
        foreach (var p in People)
        {
            var u = await db.Users.FirstOrDefaultAsync(x => x.Username == p.Username);
            if (u == null)
            {
                u = new User
                {
                    Email = EmailFor(emailBase, p.Username),
                    Username = p.Username,
                    FullName = p.FullName,
                    Role = Roles.Employee,
                    HourlyRate = p.Rate,
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword(empPw)
                };
                db.Users.Add(u);
                result.Employees++;
            }
            users[p.Username] = u;
        }
        await db.SaveChangesAsync();

        // ===== Nghỉ phép (7-9 đơn, đủ 3 trạng thái) =====
        var leaves = BuildLeaves(users, today);
        db.Leaves.AddRange(leaves);
        await db.SaveChangesAsync();
        result.Leaves = leaves.Count;

        // ===== Chấm công: gọi đúng AttendanceService với đồng hồ giả lập =====
        var clock = new SimulatedClock(offset, HistoryStart);
        var svc = new AttendanceService(new UserRepository(db), new ShiftRepository(db), new AttendanceRepository(db),
            new LeaveRepository(db), new CompanySettingsService(new SettingRepository(db)), clock, cfg);
        var company = await new CompanySettingsService(new SettingRepository(db)).GetAsync();
        var rng = new Random(20261029);
        var approved = leaves.Where(l => l.Status == LeaveStatus.Approved).ToList();

        bool OnLeave(User u, DateTime day) => approved.Any(l => l.UserId == u.Id && l.FromDate.Date <= day && day <= l.ToDate.Date);

        (double lat, double lng) Pos()
        {
            var meters = 3 + rng.NextDouble() * 55;                  // 3-58 m quanh công ty
            var angle = rng.NextDouble() * Math.PI * 2;
            return (company.Latitude + meters * Math.Cos(angle) / 111_000.0,
                    company.Longitude + meters * Math.Sin(angle) / (111_000.0 * Math.Cos(company.Latitude * Math.PI / 180)));
        }

        // Vào/ra một ca. Trả bản ghi (hoặc null nếu bị server từ chối). inMin/outMin = phút so với giờ bắt đầu / kết thúc ca.
        async Task<Attendance?> Work(User u, string shiftName, DateTime day, int inMin, int? outMin, string device,
            bool mocked = false, bool face = true, string? tag = null)
        {
            var sh = shifts[shiftName];
            var inAt = day + sh.StartTime + TimeSpan.FromMinutes(inMin) + TimeSpan.FromSeconds(rng.Next(5, 55));
            if (inAt > nowLocal) return null;                         // ca chưa bắt đầu tại thời điểm nạp
            clock.LocalNow = inAt;
            var (la, lo) = Pos();
            var r = await svc.CheckInAsync(u.Id, new CheckRequestModel
            {
                QrToken = sh.QrToken, Latitude = la, Longitude = lo, IsMocked = mocked, DeviceId = device, FaceVerified = face
            });
            if (!r.Success)
            {
                result.Warnings.Add($"{u.Username} {day:yyyy-MM-dd} {shiftName}: check-in bị từ chối ({r.Message})");
                return null;
            }
            result.Attendances++;
            var att = r.Attendance!;
            if (outMin == null) return att;

            var outAt = day + sh.EndTime + TimeSpan.FromMinutes(outMin.Value) + TimeSpan.FromSeconds(rng.Next(0, 40));
            if (outAt > nowLocal) return att;                         // ca đang diễn ra: để đang làm
            clock.LocalNow = outAt;
            var (la2, lo2) = Pos();
            var o = await svc.CheckOutAsync(u.Id, new CheckRequestModel
            {
                QrToken = sh.QrToken, Latitude = la2, Longitude = lo2, IsMocked = false, DeviceId = device, FaceVerified = face && rng.Next(100) > 4
            });
            if (!o.Success) result.Warnings.Add($"{u.Username} {day:yyyy-MM-dd} {shiftName}: check-out bị từ chối ({o.Message})");
            return o.Attendance ?? att;
        }

        int Early(int maxEarly = 12, int maxLate = 3) => rng.Next(-maxEarly, maxLate + 1);   // đúng giờ (<= ân hạn 5)
        int Late(int min, int max) => rng.Next(min, max + 1);
        var devOf = People.ToDictionary(p => p.Username, p => p.DeviceId);

        for (var day = HistoryStart; day <= today; day = day.AddDays(1))
        {
            if (day.DayOfWeek == DayOfWeek.Sunday) continue;         // nghỉ Chủ nhật
            var dayKey = day.ToString("yyyy-MM-dd");

            // 1) Lan Anh - Ca 1, đều đặn, gần như luôn đúng giờ
            var lan = users["lananh"];
            if (!OnLeave(lan, day))
            {
                var late = rng.Next(100) < 4;
                await Work(lan, FixedShifts.Ca1, day, late ? Late(6, 9) : Early(), rng.Next(0, 12), devOf["lananh"], face: rng.Next(100) > 5);
            }

            // 2) Quân - Ca 2, thỉnh thoảng trễ 8-25 phút; 09/10 quên check-out -> admin đóng ca
            var quan = users["minhquan"];
            if (!OnLeave(quan, day))
            {
                var late = rng.Next(100) < 14;
                var forgot = dayKey == "2026-10-09";
                var att = await Work(quan, FixedShifts.Ca2, day, late ? Late(8, 25) : Early(), forgot ? null : rng.Next(0, 15), devOf["minhquan"]);
                if (forgot && att != null)
                {
                    clock.LocalNow = day.AddDays(1).AddHours(9).AddMinutes(12);
                    var c = await svc.CloseAsync(att.Id, admin.Id, new TimeSpan(18, 0, 0), "Quên bấm check-out, đã gọi điện xác nhận nhân viên ra về lúc 18:00");
                    if (!c.Success) result.Warnings.Add($"Đóng ca {dayKey}: {c.Message}");
                }
            }

            // 3) Nam - Ca 3 (đêm): ổn định; 14/10 ra sớm vì việc gia đình (21:30), lương theo giờ thực làm
            var nam = users["hoangnam"];
            if (!OnLeave(nam, day))
            {
                var early = dayKey == "2026-10-14";
                await Work(nam, FixedShifts.Ca3, day, rng.Next(-8, 3), early ? -150 : -rng.Next(1, 4), devOf["hoangnam"], face: rng.Next(100) > 6);
            }

            // 4) Hà - ca gãy: ca gãy sáng, ra rồi mới vào ca gãy chiều cùng ngày
            var ha = users["thuha"];
            if (!OnLeave(ha, day))
            {
                await Work(ha, FixedShifts.GaySang, day, Early(10, 3), rng.Next(0, 10), devOf["thuha"]);
                var lateAfternoon = rng.Next(100) < 8;
                await Work(ha, FixedShifts.GayChieu, day, lateAfternoon ? Late(7, 15) : Early(), rng.Next(0, 10), devOf["thuha"], face: rng.Next(100) > 7);
            }

            // 5) Bảo - Ca 1, hay đi trễ, 2 ca nghi ngờ
            var bao = users["quocbao"];
            if (!OnLeave(bao, day))
            {
                var isToday = day == today;
                var late = rng.Next(100) < 55;
                int inMin = late ? Late(6, 35) : Early(6, 3);
                string device = devOf["quocbao"];
                var mocked = false;
                if (dayKey == "2026-10-06") { mocked = true; inMin = Late(10, 18); }                 // GPS giả
                if (dayKey == "2026-10-20") { device = devOf["lananh"]; inMin = Late(20, 28); }      // dùng chung thiết bị với Lan Anh (cùng ca, cùng ngày)
                // Hôm nay: ca đã kết thúc mà quên check-out -> bản ghi còn mở (admin xử lý bằng "Đóng ca")
                var att = await Work(bao, FixedShifts.Ca1, day, inMin, isToday ? null : rng.Next(0, 18), device,
                    mocked: mocked, face: !(mocked || rng.Next(100) < 12));
                if (dayKey == "2026-10-06" && att != null)
                {
                    clock.LocalNow = day.AddDays(1).AddHours(8).AddMinutes(40);
                    var rv = await svc.ReviewAsync(att.Id, admin.Id, "Đã gọi điện xác nhận: nhân viên bật nhầm ứng dụng giả vị trí, không có dấu hiệu gian lận");
                    if (!rv.Success) result.Warnings.Add($"Gỡ cờ {dayKey}: {rv.Message}");
                }
            }
        }

        logger.LogInformation("Dữ liệu mẫu: {E} nhân viên mới, {A} lượt chấm công, {L} đơn nghỉ.", result.Employees, result.Attendances, result.Leaves);
        return result;
    }

    private static List<Leave> BuildLeaves(Dictionary<string, User> u, DateTime today)
    {
        Leave L(string user, string from, string to, string reason, string status, string? note = null)
        {
            var f = DateTime.Parse(from, System.Globalization.CultureInfo.InvariantCulture);
            return new Leave
            {
                UserId = u[user].Id,
                FromDate = f,
                ToDate = DateTime.Parse(to, System.Globalization.CultureInfo.InvariantCulture),
                Reason = reason,
                Status = status,
                AdminNote = note,
                CreatedAt = DateTime.SpecifyKind(f.AddDays(-5), DateTimeKind.Utc)
            };
        }

        return new List<Leave>
        {
            // Đã duyệt - đã qua
            L("lananh", "2026-09-22", "2026-09-22", "Khám sức khỏe định kỳ", LeaveStatus.Approved, "Đã duyệt, nhớ gửi lại kết quả khám"),
            L("minhquan", "2026-10-02", "2026-10-02", "Con ốm, cần ở nhà chăm sóc", LeaveStatus.Approved, "Chúc bé mau khỏe"),
            L("thuha", "2026-10-12", "2026-10-13", "Về quê dự đám cưới người thân", LeaveStatus.Approved, "Đã duyệt 2 ngày"),
            // Đã duyệt - sắp tới
            L("lananh", "2026-11-06", "2026-11-07", "Về quê dự đám cưới em họ", LeaveStatus.Approved, "Đã duyệt"),
            L("hoangnam", "2026-11-09", "2026-11-09", "Giải quyết việc gia đình", LeaveStatus.Approved, "Đã duyệt, bàn giao ca cho bạn Quân"),
            // Chờ duyệt - ngày sắp tới
            L("lananh", "2026-11-12", "2026-11-12", "Làm thủ tục hành chính (gia hạn giấy tờ)", LeaveStatus.Pending),
            L("minhquan", "2026-11-03", "2026-11-03", "Khám sức khỏe định kỳ", LeaveStatus.Pending),
            L("quocbao", "2026-11-05", "2026-11-05", "Đi công chứng giấy tờ nhà", LeaveStatus.Pending),
            // Từ chối - có ghi chú admin
            L("quocbao", "2026-10-16", "2026-10-16", "Xin nghỉ đột xuất để về quê", LeaveStatus.Rejected, "Tuần này thiếu người, vui lòng sắp xếp sang ngày khác"),
        };
    }
}
