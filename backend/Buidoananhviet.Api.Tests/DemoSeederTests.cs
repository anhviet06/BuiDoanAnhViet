using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Buidoananhviet.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Buidoananhviet.Api.Tests;

/// <summary>Kiểm tra tính nhất quán của bộ dữ liệu mẫu (nạp bằng đúng AttendanceService).</summary>
public class DemoSeederTests : IAsyncLifetime
{
    private static readonly DateTime Now = new(2026, 10, 29, 19, 5, 0);   // thứ Năm, 19:05 (giờ địa phương)
    private TestEnv _env = null!;
    private DemoSeedResult _result = null!;
    private List<Attendance> _att = null!;
    private List<Leave> _leaves = null!;
    private Dictionary<string, User> _users = null!;
    private Dictionary<int, Shift> _shifts = null!;

    public async Task InitializeAsync()
    {
        _env = await TestEnv.CreateAsync(Now);
        _result = await DemoSeeder.SeedAsync(_env.Db, _env.Cfg, NullLogger.Instance, Now);
        _att = await _env.Db.Attendances.Include(a => a.Shift).Include(a => a.User).ToListAsync();
        _leaves = await _env.Db.Leaves.ToListAsync();
        _users = await _env.Db.Users.Where(u => u.Role == Roles.Employee).ToDictionaryAsync(u => u.Username);
        _shifts = await _env.Db.Shifts.ToDictionaryAsync(s => s.Id);
    }

    public Task DisposeAsync()
    {
        _env.Dispose();
        return Task.CompletedTask;
    }

    private static DateTime Local(DateTime utc) => DateTime.SpecifyKind(utc, DateTimeKind.Utc) + TestEnv.Offset;

    [Fact]
    public void Khong_co_ban_ghi_nao_bi_server_tu_choi()
    {
        Assert.Empty(_result.Warnings);
    }

    [Fact]
    public void Co_dung_5_nhan_vien_voi_email_plus_address_va_don_gia()
    {
        Assert.Equal(5, _users.Count);
        Assert.Equal("someone+lananh@gmail.com", _users["lananh"].Email);
        Assert.Equal(new[] { 35000m, 38000m, 42000m, 32000m, 30000m },
            new[] { "lananh", "minhquan", "hoangnam", "thuha", "quocbao" }.Select(n => _users[n].HourlyRate));
        Assert.Equal("Nguyễn Thị Lan Anh", _users["lananh"].FullName);
    }

    [Fact]
    public void Khong_co_hai_ban_ghi_cua_cung_nhan_vien_chong_gio()
    {
        foreach (var g in _att.GroupBy(a => a.UserId))
        {
            var spans = g.Select(a => (From: Local(a.CheckInAt), To: a.CheckOutAt == null ? Now : Local(a.CheckOutAt.Value))).OrderBy(s => s.From).ToList();
            for (var i = 1; i < spans.Count; i++)
                Assert.True(spans[i].From >= spans[i - 1].To, $"Chồng giờ: {spans[i - 1]} và {spans[i]} (user {g.Key})");
        }
    }

    [Fact]
    public void Moi_nhan_vien_toi_da_1_ban_ghi_dang_mo_va_chi_o_hom_nay()
    {
        foreach (var g in _att.GroupBy(a => a.UserId))
        {
            var open = g.Where(a => a.CheckOutAt == null).ToList();
            Assert.True(open.Count <= 1);
            Assert.All(open, a => Assert.Equal(Now.Date, a.WorkDate.Date));
        }
    }

    [Fact]
    public void Khong_co_cham_cong_trong_ngay_nghi_da_duyet_va_khong_co_Chu_nhat()
    {
        foreach (var l in _leaves.Where(l => l.Status == LeaveStatus.Approved))
            Assert.DoesNotContain(_att, a => a.UserId == l.UserId && a.WorkDate.Date >= l.FromDate.Date && a.WorkDate.Date <= l.ToDate.Date);
        Assert.DoesNotContain(_att, a => a.WorkDate.DayOfWeek == DayOfWeek.Sunday);
    }

    [Fact]
    public void Moi_check_in_nam_trong_cua_so_cho_phep_cua_ca()
    {
        foreach (var a in _att)
        {
            var s = _shifts[a.ShiftId];
            var inAt = Local(a.CheckInAt);
            Assert.True(inAt >= a.WorkDate + s.StartTime - TimeSpan.FromMinutes(30), $"quá sớm: {a.Id}");
            Assert.True(inAt <= a.WorkDate + s.EndTime, $"quá muộn: {a.Id}");
        }
    }

    [Fact]
    public void Khoang_cach_toi_cong_ty_0_den_60m()
    {
        Assert.All(_att, a => Assert.InRange(a.DistanceMeters, 0, 60));
    }

    [Fact]
    public void Lich_su_tu_14_09_den_hom_nay_co_ca_thang_9_va_thang_10()
    {
        Assert.Equal(new DateTime(2026, 9, 14), _att.Min(a => a.WorkDate));
        Assert.True(_att.Count(a => a.WorkDate.Month == 9) >= 2 * 5 * 6 / 2);
        Assert.Contains(_att, a => a.WorkDate.Date == Now.Date);
        Assert.DoesNotContain(_att, a => a.WorkDate.Date > Now.Date);
    }

    [Fact]
    public void Ca_hom_nay_chi_co_o_nhung_ca_da_bat_dau_ca_dang_dien_ra_de_dang_lam()
    {
        var today = _att.Where(a => a.WorkDate.Date == Now.Date).ToList();
        Assert.All(today, a => Assert.True(Local(a.CheckInAt) <= Now));
        // 19:05: Nam (Ca 3 từ 18:00) và Hà (Ca gãy chiều 16-20) đang làm; Bảo quên check-out Ca 1
        var open = today.Where(a => a.CheckOutAt == null).Select(a => a.User!.Username).OrderBy(x => x).ToList();
        Assert.Equal(new[] { "hoangnam", "quocbao", "thuha" }, open);
    }

    [Fact]
    public void Bao_2_ca_nghi_ngo_1_da_go_co_co_ghi_chu_1_con_treo_va_dung_cau_chu_server()
    {
        var bao = _att.Where(a => a.User!.Username == "quocbao").ToList();
        var flaggedEver = bao.Where(a => a.Status == AttendanceStatus.Suspicious || a.AdminAction == "reviewed").ToList();
        Assert.Equal(2, flaggedEver.Count);
        var reviewed = flaggedEver.Single(a => a.AdminAction == "reviewed");
        Assert.False(string.IsNullOrWhiteSpace(reviewed.AdminNote));
        Assert.Equal(_env.Admin.Id, reviewed.AdminActionByUserId);
        Assert.NotEqual(AttendanceStatus.Suspicious, reviewed.Status);
        Assert.True(reviewed.IsMockedLocation);
        Assert.Equal("GPS giả (mock location)", reviewed.SuspiciousReason);
        var pending = flaggedEver.Single(a => a.AdminAction == null);
        Assert.Equal(AttendanceStatus.Suspicious, pending.Status);
        Assert.Equal("Thiết bị này đã chấm công cho nhân viên khác trong ngày", pending.SuspiciousReason);
        var lan = _att.Single(a => a.User!.Username == "lananh" && a.WorkDate == pending.WorkDate);
        Assert.Equal(lan.DeviceId, pending.DeviceId);                                   // cặp dùng chung thiết bị
        Assert.Equal(1, bao.Count(a => a.CheckOutAt == null));                          // 1 ca quên check-out (hôm nay)
        Assert.Contains(_leaves, l => l.UserId == _users["quocbao"].Id && l.Status == LeaveStatus.Rejected && !string.IsNullOrWhiteSpace(l.AdminNote));
    }

    [Fact]
    public void Quan_1_lan_quen_check_out_duoc_admin_dong_ca_co_ghi_chu()
    {
        var closed = _att.Where(a => a.User!.Username == "minhquan" && a.AdminAction == "closed").ToList();
        var c = Assert.Single(closed);
        Assert.False(string.IsNullOrWhiteSpace(c.AdminNote));
        Assert.NotNull(c.CheckOutAt);
        Assert.Equal(6.00m, c.WorkedHours);                                              // 12:00 -> 18:00
        Assert.Equal(_env.Admin.Id, c.AdminActionByUserId);
        Assert.InRange(_att.Count(a => a.User!.Username == "minhquan" && a.LateMinutes > 0), 1, 40);
    }

    [Fact]
    public void Nam_ca_dem_co_dung_1_lan_ra_som_luong_theo_gio_thuc_lam()
    {
        var nam = _att.Where(a => a.User!.Username == "hoangnam" && a.CheckOutAt != null).ToList();
        var early = nam.Where(a => a.WorkedHours < 5m).ToList();
        var e = Assert.Single(early);
        Assert.InRange(e.WorkedHours, 3.4m, 3.6m);                                      // 18:00 -> 21:30
        Assert.Equal(Math.Round(e.WorkedHours * 42000m, 0), e.GrossPay);
        Assert.All(nam.Except(early), a => Assert.InRange(a.WorkedHours, 5.7m, 6.0m));
    }

    [Fact]
    public void Ha_lam_ca_gay_sang_roi_ca_gay_chieu_cung_ngay_va_nghi_phep_2_ngay()
    {
        var ha = _att.Where(a => a.User!.Username == "thuha").ToList();
        foreach (var day in ha.GroupBy(a => a.WorkDate))
        {
            var morning = day.SingleOrDefault(a => a.Shift!.Name == "Ca gãy sáng");
            var afternoon = day.SingleOrDefault(a => a.Shift!.Name == "Ca gãy chiều");
            if (morning != null && afternoon != null && morning.CheckOutAt != null)
                Assert.True(Local(morning.CheckOutAt.Value) <= Local(afternoon.CheckInAt));
        }
        Assert.True(ha.GroupBy(a => a.WorkDate).Count(g => g.Count() == 2) > 15);
        var leave = Assert.Single(_leaves, l => l.UserId == _users["thuha"].Id);
        Assert.Equal(2, (leave.ToDate.Date - leave.FromDate.Date).Days + 1);
        Assert.Equal(LeaveStatus.Approved, leave.Status);
    }

    [Fact]
    public void Phat_dung_quy_tac_va_luong_bang_gio_nhan_don_gia_tru_phat()
    {
        foreach (var a in _att)
        {
            Assert.Equal(a.LateMinutes * 1000m, a.LatePenalty);
            if (a.LateMinutes > 0) Assert.True(a.LateMinutes > 5);                      // chỉ phạt khi quá ân hạn
            if (a.CheckOutAt == null) continue;
            Assert.Equal(Math.Round(a.WorkedHours * a.User!.HourlyRate, 0, MidpointRounding.AwayFromZero), a.GrossPay);
            Assert.Equal(Math.Max(0, a.GrossPay - a.LatePenalty), a.Pay);
        }
    }

    [Fact]
    public void Co_7_den_9_don_nghi_du_3_trang_thai_khong_cham_cong_ngay_da_duyet()
    {
        Assert.InRange(_leaves.Count, 7, 9);
        Assert.Contains(_leaves, l => l.Status == LeaveStatus.Pending);
        Assert.Contains(_leaves, l => l.Status == LeaveStatus.Approved && l.ToDate < Now.Date);
        Assert.Contains(_leaves, l => l.Status == LeaveStatus.Approved && l.FromDate > Now.Date);
        Assert.Contains(_leaves, l => l.Status == LeaveStatus.Rejected);
        Assert.All(_leaves.Where(l => l.Status == LeaveStatus.Pending), l => Assert.True(l.FromDate > Now.Date));
        Assert.All(_leaves.Where(l => l.Status == LeaveStatus.Rejected), l => Assert.False(string.IsNullOrWhiteSpace(l.AdminNote)));
    }

    [Fact]
    public void Moi_nhan_vien_co_deviceId_rieng_tru_cap_dung_chung()
    {
        var devices = _att.GroupBy(a => a.User!.Username).ToDictionary(g => g.Key, g => g.Select(a => a.DeviceId).Distinct().ToList());
        Assert.All(devices, kv => Assert.True(kv.Value.Count <= 2));
        Assert.Single(devices["lananh"]);
        Assert.Equal(2, devices["quocbao"].Count);                                       // thiết bị riêng + 1 ngày dùng của Lan Anh
        var own = devices.Where(kv => kv.Key != "quocbao").Select(kv => kv.Value.Single()).ToList();
        Assert.Equal(own.Count, own.Distinct().Count());
    }

    [Fact]
    public async Task Bao_cao_thang_khop_tong_cac_ban_ghi()
    {
        var reports = new ReportService(new UserRepository(_env.Db), new AttendanceRepository(_env.Db), new LeaveRepository(_env.Db));
        foreach (var (year, month) in new[] { (2026, 9), (2026, 10) })
        {
            var rep = await reports.GetMonthlyAsync(year, month, null);
            var inMonth = _att.Where(a => a.WorkDate.Year == year && a.WorkDate.Month == month).ToList();
            var done = inMonth.Where(a => a.CheckOutAt != null).ToList();
            Assert.Equal(done.Sum(a => a.WorkedHours), rep.TotalHours);
            Assert.Equal(done.Sum(a => a.LatePenalty), rep.TotalPenalty);
            Assert.Equal(done.Sum(a => a.Pay), rep.TotalNetPay);
            Assert.Equal(inMonth.Count(a => a.Status == AttendanceStatus.Suspicious), rep.TotalSuspicious);
            Assert.Equal(5, rep.Rows.Count);
            Assert.True(rep.TotalHours > 0);
        }
    }

    [Fact]
    public async Task Xoa_admin_khong_loi_o_view_bao_cao_va_khong_bi_chan_boi_hanh_dong_admin()
    {
        var adminId = _env.Admin.Id;
        Assert.Contains(_att, a => a.AdminActionByUserId == adminId);
        Assert.False(await new AttendanceRepository(_env.Db).HasAttendanceForUserAsync(adminId));   // xóa admin không bị 409

        _env.Db.Users.Remove(_env.Admin);
        await _env.Db.SaveChangesAsync();

        var list = await new AttendanceRepository(_env.Db).GetAttendancesAsync(null, null, null, null);
        var views = list.Select(AttendanceView.From).ToList();                          // không ném lỗi
        Assert.Equal(_att.Count, views.Count);
        var rep = await new ReportService(new UserRepository(_env.Db), new AttendanceRepository(_env.Db), new LeaveRepository(_env.Db)).GetMonthlyAsync(2026, 10, null);
        Assert.Equal(5, rep.Rows.Count);
    }

    [Fact]
    public async Task Nap_lai_hai_lan_khong_tao_trung_nhan_vien()
    {
        using var env2 = await TestEnv.CreateAsync(Now);
        await DemoSeeder.SeedAsync(env2.Db, env2.Cfg, NullLogger.Instance, Now);
        Assert.Equal(5, await env2.Db.Users.CountAsync(u => u.Role == Roles.Employee));
        Assert.Equal(_att.Count, await env2.Db.Attendances.CountAsync());                // tất định (Random seed cố định)
    }
}
