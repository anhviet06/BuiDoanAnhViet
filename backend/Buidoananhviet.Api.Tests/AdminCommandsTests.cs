using Buidoananhviet.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace Buidoananhviet.Api.Tests;

public class AdminCommandsTests
{
    [Fact]
    public async Task Make_admin_tim_email_khong_phan_biet_hoa_thuong_va_doi_role()
    {
        using var env = await TestEnv.CreateAsync();
        var u = await env.AddEmployeeAsync("nv");
        u.Email = "Real.Person@Gmail.com";
        await env.Db.SaveChangesAsync();
        var w = new StringWriter();

        var code = await AdminCommands.RunAsync(new[] { "--make-admin", "real.PERSON@gmail.COM" }, env.Db, env.Cfg, NullLogger.Instance, true, w);

        Assert.Equal(0, code);
        Assert.Equal(Roles.Admin, (await env.Db.Users.SingleAsync(x => x.Id == u.Id)).Role);
        Assert.Contains("employee -> admin", w.ToString());
        Assert.Contains("ĐĂNG XUẤT", w.ToString());
    }

    [Fact]
    public async Task Make_admin_da_dung_vai_tro_thi_bao_khong_doi()
    {
        using var env = await TestEnv.CreateAsync();
        var w = new StringWriter();
        var code = await AdminCommands.RunAsync(new[] { "--make-admin", "admin@timeguard.local" }, env.Db, env.Cfg, NullLogger.Instance, true, w);
        Assert.Equal(0, code);
        Assert.Contains("đã là 'admin'", w.ToString());
    }

    [Fact]
    public async Task Make_employee_va_khong_tim_thay_email()
    {
        using var env = await TestEnv.CreateAsync();
        var w = new StringWriter();
        Assert.Equal(3, await AdminCommands.RunAsync(new[] { "--make-employee", "nobody@x.com" }, env.Db, env.Cfg, NullLogger.Instance, true, w));
        Assert.Contains("Không tìm thấy", w.ToString());
        Assert.Equal(0, await AdminCommands.RunAsync(new[] { "--make-employee", "admin@timeguard.local" }, env.Db, env.Cfg, NullLogger.Instance, true, new StringWriter()));
        Assert.Equal(Roles.Employee, (await env.Db.Users.SingleAsync(x => x.Username == "admin")).Role);
    }

    [Fact]
    public async Task Chi_chay_o_Development()
    {
        using var env = await TestEnv.CreateAsync();
        var w = new StringWriter();
        var code = await AdminCommands.RunAsync(new[] { "--make-admin", "admin@timeguard.local" }, env.Db, env.Cfg, NullLogger.Instance, false, w);
        Assert.Equal(2, code);
        Assert.Contains("Development", w.ToString());
    }

    [Fact]
    public async Task Thieu_email_thi_bao_cu_phap()
    {
        using var env = await TestEnv.CreateAsync();
        var w = new StringWriter();
        Assert.Equal(1, await AdminCommands.RunAsync(new[] { "--make-admin" }, env.Db, env.Cfg, NullLogger.Instance, true, w));
        Assert.Contains("Thiếu email", w.ToString());
    }
}

public class SeedDemoOnlyTests
{
    [Fact]
    public async Task Seed_demo_chi_them_khong_xoa_admin_va_tu_choi_khi_da_co_du_lieu()
    {
        using var env = await TestEnv.CreateAsync(new DateTime(2026, 10, 29, 19, 5, 0));
        var admin = await env.Db.Users.SingleAsync(u => u.Username == "admin");
        admin.Username = "chu-he-thong";                          // admin không tên "admin" như trên DB deploy
        await env.Db.SaveChangesAsync();
        var w = new StringWriter();

        Assert.Equal(0, await AdminCommands.SeedDemoOnlyAsync(env.Db, env.Cfg, NullLogger.Instance, w));
        Assert.Equal(5, await env.Db.Users.CountAsync(u => u.Role == Roles.Employee));
        Assert.Equal(1, await env.Db.Users.CountAsync(u => u.Role == Roles.Admin));
        Assert.True(await env.Db.Attendances.AnyAsync());

        var w2 = new StringWriter();
        Assert.Equal(5, await AdminCommands.SeedDemoOnlyAsync(env.Db, env.Cfg, NullLogger.Instance, w2));
        Assert.Contains("Từ chối", w2.ToString());
        Assert.Equal(5, await env.Db.Users.CountAsync(u => u.Role == Roles.Employee));
    }

    [Fact]
    public async Task Seed_demo_dung_neu_khong_co_admin()
    {
        using var env = await TestEnv.CreateAsync(withAdmin: false);
        Assert.Equal(4, await AdminCommands.SeedDemoOnlyAsync(env.Db, env.Cfg, NullLogger.Instance, new StringWriter()));
        Assert.Equal(0, await env.Db.Users.CountAsync());
    }
}
