using System.Text.Json;
using System.Text.RegularExpressions;
using Buidoananhviet.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Buidoananhviet.Api.Tests;

public class ShiftTimeTests
{
    [Fact]
    public void Parse_24h_la_het_ngay_va_hien_thi_lai_24h()
    {
        Assert.True(ShiftTime.TryParse("24:00", out var t));
        Assert.Equal(ShiftTime.EndOfDay, t);
        Assert.Equal("24:00", ShiftTime.Format(t));
        Assert.Equal("23:30", ShiftTime.Format(new TimeSpan(23, 30, 0)));
        Assert.Equal("06:00", ShiftTime.Format(new TimeSpan(6, 0, 0)));
    }

    [Fact]
    public void Parse_gio_khong_hop_le()
    {
        Assert.False(ShiftTime.TryParse("25:00", out _));
        Assert.False(ShiftTime.TryParse("abc", out _));
        Assert.False(ShiftTime.TryParse("", out _));
    }

    [Fact]
    public void ShiftModel_json_nhan_24h()
    {
        var m = JsonSerializer.Deserialize<ShiftModel>("{\"name\":\"Ca 3\",\"startTime\":\"18:00\",\"endTime\":\"24:00\",\"lateGraceMinutes\":5,\"isActive\":true}",
            new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        Assert.Equal(new TimeSpan(18, 0, 0), m.StartTime);
        Assert.Equal(ShiftTime.EndOfDay, m.EndTime);
        Assert.True(m.EndTime > m.StartTime);
    }

    [Fact]
    public void Gio_ket_thuc_hop_le_voi_cot_time_cua_SQL()
    {
        // SQL Server time(7) tối đa 23:59:59.9999999 -> EndOfDay phải nhỏ hơn 1 ngày
        Assert.True(ShiftTime.EndOfDay < TimeSpan.FromDays(1));
    }
}

public class FixedShiftsTests
{
    private static readonly Regex TokenRe = new(@"^TG-(CA1|CA2|CA3|GAYS|GAYC)-[A-HJ-NP-Z2-9]{8}$");

    [Fact]
    public void Dung_5_ca_voi_ten_gio_va_token_co_dinh_khong_trung()
    {
        var all = FixedShifts.All;
        Assert.Equal(new[] { "Ca 1", "Ca 2", "Ca 3", "Ca gãy sáng", "Ca gãy chiều" }, all.Select(s => s.Name));
        Assert.Equal(5, all.Select(s => s.QrToken).Distinct().Count());
        foreach (var s in all) Assert.Matches(TokenRe, s.QrToken);
        Assert.Equal((new TimeSpan(6, 0, 0), new TimeSpan(12, 0, 0)), (all[0].Start, all[0].End));
        Assert.Equal((new TimeSpan(12, 0, 0), new TimeSpan(18, 0, 0)), (all[1].Start, all[1].End));
        Assert.Equal((new TimeSpan(18, 0, 0), ShiftTime.EndOfDay), (all[2].Start, all[2].End));
        Assert.Equal((new TimeSpan(5, 0, 0), new TimeSpan(9, 0, 0)), (all[3].Start, all[3].End));
        Assert.Equal((new TimeSpan(16, 0, 0), new TimeSpan(20, 0, 0)), (all[4].Start, all[4].End));
        Assert.All(all, s => Assert.True(s.End > s.Start));
    }
}

public class SyncShiftsTests
{
    [Fact]
    public async Task Doi_ten_2_ca_cu_giu_Id_them_3_ca_con_lai_va_idempotent()
    {
        using var env = new TestEnv();
        env.Db.Shifts.AddRange(
            new Shift { Name = "Ca sáng", StartTime = new(8, 0, 0), EndTime = new(12, 0, 0) },
            new Shift { Name = "Ca chiều", StartTime = new(13, 30, 0), EndTime = new(17, 30, 0) });
        await env.Db.SaveChangesAsync();
        var oldIds = await env.Db.Shifts.OrderBy(s => s.Id).Select(s => s.Id).ToListAsync();

        for (var i = 0; i < 3; i++) await DbSeeder.SyncShiftsAsync(env.Db, NullLogger.Instance, forceDefinition: false);

        var shifts = await env.Db.Shifts.OrderBy(s => s.Id).ToListAsync();
        Assert.Equal(5, shifts.Count);
        Assert.Equal("Ca 1", shifts.First(s => s.Id == oldIds[0]).Name);
        Assert.Equal("Ca 2", shifts.First(s => s.Id == oldIds[1]).Name);
        Assert.Equal(new TimeSpan(6, 0, 0), shifts.First(s => s.Id == oldIds[0]).StartTime);
        Assert.All(FixedShifts.All, f => Assert.Equal(f.QrToken, shifts.Single(s => s.Name == f.Name).QrToken));
    }

    [Fact]
    public async Task Khoi_dong_lai_khong_doi_gio_admin_da_sua()
    {
        using var env = await TestEnv.CreateAsync();
        var ca2 = await env.Db.Shifts.SingleAsync(s => s.Name == "Ca 2");
        ca2.StartTime = new(12, 30, 0);          // admin chỉnh giờ
        await env.Db.SaveChangesAsync();

        await DbSeeder.SyncShiftsAsync(env.Db, NullLogger.Instance, forceDefinition: false);

        ca2 = await env.Db.Shifts.SingleAsync(s => s.Name == "Ca 2");
        Assert.Equal(new TimeSpan(12, 30, 0), ca2.StartTime);
        Assert.Equal(FixedShifts.Get("Ca 2").QrToken, ca2.QrToken);
    }

    [Fact]
    public async Task Admin_doi_ma_QR_roi_khoi_dong_lai_thi_ep_ve_ma_co_dinh()
    {
        using var env = await TestEnv.CreateAsync();
        var s = await env.Db.Shifts.SingleAsync(x => x.Name == "Ca 1");
        s.QrToken = "doi-ma-bang-nut-admin";
        await env.Db.SaveChangesAsync();
        await DbSeeder.SyncShiftsAsync(env.Db, NullLogger.Instance, forceDefinition: false);
        Assert.Equal(FixedShifts.Get("Ca 1").QrToken, (await env.Db.Shifts.SingleAsync(x => x.Name == "Ca 1")).QrToken);
    }

    [Fact]
    public async Task Don_ca_rac_cua_test_neu_chua_co_cham_cong_con_co_thi_giu()
    {
        using var env = await TestEnv.CreateAsync();
        var e = await env.AddEmployeeAsync("nv");
        env.Db.Shifts.AddRange(new Shift { Name = "Ca ET 123", StartTime = new(1, 0, 0), EndTime = new(2, 0, 0) },
            new Shift { Name = "Ca RP 456", StartTime = new(1, 0, 0), EndTime = new(2, 0, 0) },
            new Shift { Name = "Ca UI test", StartTime = new(1, 0, 0), EndTime = new(2, 0, 0) });
        await env.Db.SaveChangesAsync();
        var keepId = (await env.Db.Shifts.SingleAsync(s => s.Name == "Ca RP 456")).Id;
        env.Db.Attendances.Add(new Attendance { UserId = e.Id, ShiftId = keepId, WorkDate = new DateTime(2026, 10, 1), CheckInAt = DateTime.UtcNow });
        await env.Db.SaveChangesAsync();

        await DbSeeder.SyncShiftsAsync(env.Db, NullLogger.Instance, forceDefinition: false);

        var names = await env.Db.Shifts.Select(s => s.Name).ToListAsync();
        Assert.DoesNotContain("Ca ET 123", names);
        Assert.DoesNotContain("Ca UI test", names);
        Assert.Contains("Ca RP 456", names);
        Assert.Equal(6, names.Count);
    }

    [Fact]
    public async Task Seed_khoi_dong_khong_tao_user_nao_ke_ca_khi_admin_bi_xoa()
    {
        using var env = await TestEnv.CreateAsync(withAdmin: false);
        for (var i = 0; i < 3; i++) await DbSeeder.SeedAsync(env.Db, env.Cfg, NullLogger.Instance);
        Assert.Equal(0, await env.Db.Users.CountAsync());
        Assert.Equal(5, await env.Db.Shifts.CountAsync());
        Assert.Equal(4, await env.Db.Settings.CountAsync());
    }
}
