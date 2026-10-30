using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Services;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Tests;

public class DeviceLoginTests
{
    private static async Task<(TestEnv env, DeviceLoginService svc, User user)> Setup()
    {
        var env = await TestEnv.CreateAsync(new DateTime(2026, 10, 30, 9, 0, 0));
        var svc = new DeviceLoginService(env.Db, env.Clock);
        var user = await env.AddEmployeeAsync("lananh");
        return (env, svc, user);
    }

    [Fact]
    public async Task Cap_token_roi_dang_nhap_duoc_va_server_chi_luu_bam()
    {
        var (env, svc, u) = await Setup();
        using var _ = env;
        var (token, exp) = await svc.IssueAsync(u.Id, "dev-A");

        Assert.True(token.Length >= 43);
        Assert.Equal(env.Clock.UtcNow + TimeSpan.FromDays(30), exp);
        var row = await env.Db.DeviceLogins.SingleAsync();
        Assert.NotEqual(token, row.TokenHash);                    // không lưu token thô
        Assert.Equal(DeviceLoginService.Hash(token), row.TokenHash);
        Assert.Equal(64, row.TokenHash.Length);

        var user = await svc.ValidateAsync("dev-A", token);
        Assert.Equal(u.Id, user!.Id);
        Assert.NotNull((await env.Db.DeviceLogins.SingleAsync()).LastUsedAt);
    }

    [Fact]
    public async Task Sai_token_sai_thiet_bi_hoac_token_khong_ton_tai_deu_bi_tu_choi()
    {
        var (env, svc, u) = await Setup();
        using var _ = env;
        var (token, _) = await svc.IssueAsync(u.Id, "dev-A");
        Assert.Null(await svc.ValidateAsync("dev-A", token + "x"));
        Assert.Null(await svc.ValidateAsync("dev-B", token));      // token của thiết bị khác
        Assert.Null(await svc.ValidateAsync("dev-A", "khong-co"));
    }

    [Fact]
    public async Task Het_han_sau_30_ngay()
    {
        var (env, svc, u) = await Setup();
        using var _ = env;
        var (token, _) = await svc.IssueAsync(u.Id, "dev-A");
        env.Clock.LocalNow = env.Clock.LocalNow.AddDays(29).AddHours(23);
        Assert.NotNull(await svc.ValidateAsync("dev-A", token));
        env.Clock.LocalNow = env.Clock.LocalNow.AddHours(2);       // quá 30 ngày
        Assert.Null(await svc.ValidateAsync("dev-A", token));
    }

    [Fact]
    public async Task Thu_hoi_thi_het_hieu_luc_va_thu_hoi_hai_lan_khong_loi()
    {
        var (env, svc, u) = await Setup();
        using var _ = env;
        var (token, _) = await svc.IssueAsync(u.Id, "dev-A");
        Assert.True(await svc.RevokeAsync("dev-A", token));
        Assert.Null(await svc.ValidateAsync("dev-A", token));
        Assert.False(await svc.RevokeAsync("dev-A", token));
        Assert.False(await svc.RevokeAsync("dev-B", token));
    }

    [Fact]
    public async Task Cap_lai_cho_cung_thiet_bi_thi_token_cu_het_hieu_luc()
    {
        var (env, svc, u) = await Setup();
        using var _ = env;
        var (t1, _) = await svc.IssueAsync(u.Id, "dev-A");
        var (t2, _) = await svc.IssueAsync(u.Id, "dev-A");
        Assert.NotEqual(t1, t2);
        Assert.Null(await svc.ValidateAsync("dev-A", t1));
        Assert.NotNull(await svc.ValidateAsync("dev-A", t2));
    }

    [Fact]
    public async Task Thu_hoi_tat_ca_khi_doi_mat_khau_chi_anh_huong_dung_nguoi_dung()
    {
        var (env, svc, u) = await Setup();
        using var _ = env;
        var other = await env.AddEmployeeAsync("minhquan");
        var (t1, _) = await svc.IssueAsync(u.Id, "dev-A");
        var (t2, _) = await svc.IssueAsync(u.Id, "dev-B");
        var (t3, _) = await svc.IssueAsync(other.Id, "dev-C");

        await svc.RevokeAllAsync(u.Id);

        Assert.Null(await svc.ValidateAsync("dev-A", t1));
        Assert.Null(await svc.ValidateAsync("dev-B", t2));
        Assert.NotNull(await svc.ValidateAsync("dev-C", t3));
    }

    [Fact]
    public async Task Tai_khoan_bi_khoa_khong_dang_nhap_duoc_mo_khoa_lai_thi_duoc_neu_token_con_hieu_luc()
    {
        var (env, svc, u) = await Setup();
        using var _ = env;
        var (token, _) = await svc.IssueAsync(u.Id, "dev-A");
        u.IsLocked = true;
        await env.Db.SaveChangesAsync();
        Assert.Null(await svc.ValidateAsync("dev-A", token));
        u.IsLocked = false;
        await env.Db.SaveChangesAsync();
        Assert.NotNull(await svc.ValidateAsync("dev-A", token));
    }

    [Fact]
    public async Task Role_lay_tu_DB_nen_nang_quyen_co_hieu_luc_ngay_o_lan_dang_nhap_ke_tiep()
    {
        var (env, svc, u) = await Setup();
        using var _ = env;
        var (token, _) = await svc.IssueAsync(u.Id, "dev-A");
        u.Role = Roles.Admin;
        await env.Db.SaveChangesAsync();
        Assert.Equal(Roles.Admin, (await svc.ValidateAsync("dev-A", token))!.Role);
    }

    [Fact]
    public async Task Xoa_nguoi_dung_xoa_luon_token_thiet_bi()
    {
        // InMemory khong ep rang buoc FK, nen xoa ca hai o day; kiem tra o muc ung dung: token cua nguoi dung da xoa khong dung duoc
        var (env, svc, u) = await Setup();
        using var _ = env;
        var (token, _) = await svc.IssueAsync(u.Id, "dev-A");
        env.Db.Users.Remove(u);
        await env.Db.SaveChangesAsync();
        Assert.Null(await svc.ValidateAsync("dev-A", token));
    }
}
