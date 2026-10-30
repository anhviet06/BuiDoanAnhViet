using Buidoananhviet.Api.Models;

namespace Buidoananhviet.Api.Tests;

public class ProfileRulesTests
{
    private static readonly DateTime Today = new(2026, 10, 30);

    private static User NewUser() => new() { FullName = "Nguyễn Văn An", Phone = "0912345678", DateOfBirth = new DateTime(2000, 5, 20), Address = "12 Lê Lợi, Q1" };

    [Fact]
    public void Tuong_thich_nguoc_chi_gui_ho_ten_thi_cac_truong_khac_giu_nguyen()
    {
        var u = NewUser();
        Assert.Null(ProfileRules.Apply(u, new ProfileUpdateModel { FullName = "  Nguyễn An Khang  " }, Today));
        Assert.Equal("Nguyễn An Khang", u.FullName);
        Assert.Equal("0912345678", u.Phone);
        Assert.Equal(new DateTime(2000, 5, 20), u.DateOfBirth);
        Assert.Equal("12 Lê Lợi, Q1", u.Address);
    }

    [Fact]
    public void Khong_gui_gi_thi_khong_doi_gi()
    {
        var u = NewUser();
        Assert.Null(ProfileRules.Apply(u, new ProfileUpdateModel(), Today));
        Assert.Equal("Nguyễn Văn An", u.FullName);
        Assert.Equal("0912345678", u.Phone);
    }

    [Fact]
    public void Cap_nhat_day_du_va_chuan_hoa_sdt()
    {
        var u = new User { FullName = "A" };
        var err = ProfileRules.Apply(u, new ProfileUpdateModel { FullName = "Lê Hoàng Nam", Phone = "+84 912.345.678", DateOfBirth = "1999-12-31", Address = "  45 Trần Hưng Đạo  " }, Today);
        Assert.Null(err);
        Assert.Equal("0912345678", u.Phone);
        Assert.Equal(new DateTime(1999, 12, 31), u.DateOfBirth);
        Assert.Equal("45 Trần Hưng Đạo", u.Address);
    }

    [Theory]
    [InlineData("0912345678", "0912345678")]
    [InlineData("091 234 5678", "0912345678")]
    [InlineData("+84912345678", "0912345678")]
    [InlineData("84912345678", "0912345678")]
    [InlineData("0352-345-678", "0352345678")]
    public void Sdt_hop_le(string input, string expected) => Assert.Equal(expected, ProfileRules.NormalizePhone(input));

    [Theory]
    [InlineData("12345")]
    [InlineData("0112345678")]      // đầu số không phải di động
    [InlineData("091234567")]       // thiếu số
    [InlineData("09123456789")]     // thừa số
    [InlineData("abcdefghij")]
    public void Sdt_khong_hop_le_bi_tu_choi_va_khong_ghi_gi(string phone)
    {
        var u = NewUser();
        var err = ProfileRules.Apply(u, new ProfileUpdateModel { FullName = "Tên mới", Phone = phone }, Today);
        Assert.Equal("Số điện thoại không hợp lệ (ví dụ 0912345678)", err);
        Assert.Equal("Nguyễn Văn An", u.FullName);          // lỗi thì KHÔNG ghi bất kỳ thay đổi nào
        Assert.Equal("0912345678", u.Phone);
    }

    [Fact]
    public void Ngay_sinh_tuong_lai_hoac_sai_dinh_dang_bi_tu_choi_hom_nay_thi_duoc()
    {
        Assert.Equal("Ngày sinh không được ở tương lai", ProfileRules.Apply(NewUser(), new ProfileUpdateModel { DateOfBirth = "2026-10-31" }, Today));
        Assert.Equal("Ngày sinh không hợp lệ (định dạng yyyy-MM-dd)", ProfileRules.Apply(NewUser(), new ProfileUpdateModel { DateOfBirth = "30/10/2000" }, Today));
        Assert.Equal("Ngày sinh không hợp lệ", ProfileRules.Apply(NewUser(), new ProfileUpdateModel { DateOfBirth = "1850-01-01" }, Today));
        var u = NewUser();
        Assert.Null(ProfileRules.Apply(u, new ProfileUpdateModel { DateOfBirth = "2026-10-30" }, Today));
        Assert.Equal(new DateTime(2026, 10, 30), u.DateOfBirth);
    }

    [Fact]
    public void Dia_chi_toi_da_200_ky_tu()
    {
        var ok = NewUser();
        Assert.Null(ProfileRules.Apply(ok, new ProfileUpdateModel { Address = new string('a', 200) }, Today));
        Assert.Equal(200, ok.Address!.Length);
        var bad = NewUser();
        Assert.Equal("Địa chỉ tối đa 200 ký tự", ProfileRules.Apply(bad, new ProfileUpdateModel { Address = new string('a', 201) }, Today));
        Assert.Equal("12 Lê Lợi, Q1", bad.Address);
    }

    [Fact]
    public void Chuoi_rong_xoa_sdt_ngay_sinh_dia_chi_nhung_ho_ten_khong_duoc_rong()
    {
        var u = NewUser();
        Assert.Null(ProfileRules.Apply(u, new ProfileUpdateModel { Phone = "", DateOfBirth = " ", Address = "" }, Today));
        Assert.Null(u.Phone);
        Assert.Null(u.DateOfBirth);
        Assert.Null(u.Address);

        var v = NewUser();
        Assert.Equal("Họ và tên không được để trống", ProfileRules.Apply(v, new ProfileUpdateModel { FullName = "   " }, Today));
        Assert.Equal("Nguyễn Văn An", v.FullName);
        Assert.Equal("Họ và tên tối đa 100 ký tự", ProfileRules.Apply(v, new ProfileUpdateModel { FullName = new string('a', 101) }, Today));
    }
}
