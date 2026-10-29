using Buidoananhviet.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Tests;

public class AttendanceRulesTests
{
    private static readonly DateTime D = new(2026, 10, 29);

    // ===== Ca 3 (18:00 - 24:00) =====

    [Fact]
    public async Task Ca3_check_in_luc_23h50_hop_le()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        var r = await env.CheckIn(u, "Ca 3", D.AddHours(23).AddMinutes(50));
        Assert.True(r.Success, r.Message);
    }

    [Fact]
    public async Task Ca3_gio_lam_toi_da_6_gio_du_check_out_sat_nua_dem()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv", 42000);
        Assert.True((await env.CheckIn(u, "Ca 3", D.AddHours(18))).Success);
        var o = await env.CheckOut(u, "Ca 3", D.AddHours(23).AddMinutes(59).AddSeconds(59).AddMilliseconds(999));
        Assert.True(o.Success, o.Message);
        Assert.Equal(6.00m, o.Attendance!.WorkedHours);
        Assert.Equal(252000m, o.Attendance.GrossPay);
    }

    [Fact]
    public async Task Ca3_check_out_sau_nua_dem_van_duoc_va_tinh_toi_24h()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv", 30000);
        Assert.True((await env.CheckIn(u, "Ca 3", D.AddHours(23).AddMinutes(50))).Success);
        var o = await env.CheckOut(u, "Ca 3", D.AddDays(1).AddMinutes(5));        // 00:05 ngày hôm sau
        Assert.True(o.Success, o.Message);
        Assert.Equal(0.17m, o.Attendance!.WorkedHours);                           // 23:50 -> 24:00 = 10 phút
        Assert.Equal(D, o.Attendance.WorkDate);                                    // vẫn thuộc ngày làm việc hôm trước
        Assert.NotNull(o.Attendance.CheckOutAt);
    }

    [Fact]
    public async Task Ca3_check_in_dung_gio_khong_tre_va_tre_thi_phat_tu_gio_bat_dau()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        var r = await env.CheckIn(u, "Ca 3", D.AddHours(18).AddMinutes(20));
        Assert.Equal(AttendanceStatus.Late, r.Attendance!.Status);
        Assert.Equal(20, r.Attendance.LateMinutes);
        Assert.Equal(20_000m, r.Attendance.LatePenalty);
    }

    // ===== Không chấm 2 ca cùng lúc =====

    [Fact]
    public async Task Dang_trong_ca_chua_check_out_thi_check_in_ca_khac_bi_409_va_khong_luu()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        Assert.True((await env.CheckIn(u, "Ca gãy sáng", D.AddHours(7))).Success);          // 05-09
        var before = await env.Db.Attendances.CountAsync();

        var r = await env.CheckIn(u, "Ca 1", D.AddHours(7).AddMinutes(30));                 // Ca 1 06-12 chồng giờ
        Assert.False(r.Success);
        Assert.Equal(409, r.StatusCode);
        Assert.Equal("Bạn đang trong Ca gãy sáng chưa check-out. Hãy check-out ca đó trước khi chấm ca khác.", r.Message);
        Assert.Equal(before, await env.Db.Attendances.CountAsync());
    }

    [Fact]
    public async Task Sau_khi_check_out_thi_cham_ca_khac_binh_thuong_ke_ca_ca_chong_gio()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        Assert.True((await env.CheckIn(u, "Ca gãy sáng", D.AddHours(7))).Success);
        Assert.True((await env.CheckOut(u, "Ca gãy sáng", D.AddHours(8))).Success);
        var r = await env.CheckIn(u, "Ca 1", D.AddHours(8).AddMinutes(5));
        Assert.True(r.Success, r.Message);
        // giờ làm tính từ lúc vào nên không trùng: Ca 1 từ 08:05 tới 12:00
        var o = await env.CheckOut(u, "Ca 1", D.AddHours(12).AddMinutes(10));
        Assert.Equal(3.92m, o.Attendance!.WorkedHours);
    }

    [Fact]
    public async Task Ca_da_qua_gio_ma_quen_check_out_khong_chan_ca_sau()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        Assert.True((await env.CheckIn(u, "Ca 1", D.AddHours(6))).Success);                // 06-12, không check-out
        var r = await env.CheckIn(u, "Ca 2", D.AddHours(12).AddMinutes(30));                // đã quá 12:00
        Assert.True(r.Success, r.Message);
        Assert.Equal(1, await env.Db.Attendances.CountAsync(a => a.CheckOutAt == null && a.ShiftId != r.Attendance!.ShiftId));
    }

    [Fact]
    public async Task Cung_ca_dang_mo_van_bao_da_check_in_ca_nay()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        Assert.True((await env.CheckIn(u, "Ca 1", D.AddHours(7))).Success);
        var r = await env.CheckIn(u, "Ca 1", D.AddHours(7).AddMinutes(5));
        Assert.Equal(409, r.StatusCode);
        Assert.Equal("Bạn đã check-in ca này hôm nay", r.Message);
    }

    [Fact]
    public async Task Check_out_phai_dung_QR_cua_ca_dang_mo()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        Assert.True((await env.CheckIn(u, "Ca gãy sáng", D.AddHours(7))).Success);
        var r = await env.CheckOut(u, "Ca 1", D.AddHours(8));                               // quét QR ca khác
        Assert.False(r.Success);
        Assert.Equal("Bạn chưa check-in ca này hôm nay", r.Message);
        Assert.True((await env.CheckOut(u, "Ca gãy sáng", D.AddHours(8))).Success);
    }

    [Fact]
    public async Task Nhan_vien_khac_khong_bi_anh_huong_boi_ca_dang_mo_cua_nguoi_khac()
    {
        using var env = await TestEnv.CreateAsync();
        var a = await env.AddEmployeeAsync("a");
        var b = await env.AddEmployeeAsync("b");
        Assert.True((await env.CheckIn(a, "Ca gãy sáng", D.AddHours(7), "devA")).Success);
        Assert.True((await env.CheckIn(b, "Ca 1", D.AddHours(7).AddMinutes(10), "devB")).Success);
    }

    // ===== Ca chồng giờ + chỉ mục 1 lần/ca/ngày =====

    [Fact]
    public async Task Hai_ngay_lien_tiep_cung_ca_ok_nhung_cung_ca_cung_ngay_thi_khong()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        Assert.True((await env.CheckIn(u, "Ca 2", D.AddHours(12))).Success);
        Assert.True((await env.CheckOut(u, "Ca 2", D.AddHours(18))).Success);
        Assert.Equal(409, (await env.CheckIn(u, "Ca 2", D.AddHours(18).AddMinutes(-1))).StatusCode);
        Assert.True((await env.CheckIn(u, "Ca 2", D.AddDays(1).AddHours(12))).Success);
    }

    [Fact]
    public async Task Ngoai_cua_so_check_in_bi_400()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        var early = await env.CheckIn(u, "Ca 2", D.AddHours(11).AddMinutes(20));            // sớm hơn 30 phút
        Assert.Equal(400, early.StatusCode);
        var ended = await env.CheckIn(u, "Ca 1", D.AddHours(12).AddMinutes(1));
        Assert.Equal("Ca làm việc đã kết thúc", ended.Message);
    }
}
