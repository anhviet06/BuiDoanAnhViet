using System.Globalization;
using System.Text.RegularExpressions;

namespace Buidoananhviet.Api.Models;

/// <summary>
/// Quy tắc cập nhật hồ sơ cá nhân (PUT /api/Users/me). Tương thích ngược: trường KHÔNG gửi (null) = giữ nguyên;
/// chuỗi rỗng = xóa (SĐT, ngày sinh, địa chỉ). Họ tên không được xóa.
/// </summary>
public static class ProfileRules
{
    public const int MaxFullName = 100;
    public const int MaxAddress = 200;
    private static readonly Regex VnMobile = new(@"^0[35789]\d{8}$", RegexOptions.Compiled);

    /// <summary>Chuẩn hóa SĐT Việt Nam về dạng 0xxxxxxxxx (bỏ khoảng trắng, dấu chấm, gạch; +84/84 -> 0). Null nếu không hợp lệ.</summary>
    public static string? NormalizePhone(string input)
    {
        var s = Regex.Replace(input.Trim(), @"[\s.\-()]", "");
        if (s.StartsWith("+84")) s = "0" + s[3..];
        else if (s.StartsWith("84") && s.Length == 11) s = "0" + s[2..];
        return VnMobile.IsMatch(s) ? s : null;
    }

    /// <summary>Áp dụng thay đổi lên [user]. Trả về thông báo lỗi (tiếng Việt) nếu không hợp lệ, null nếu thành công
    /// (khi lỗi, [user] KHÔNG bị thay đổi). [todayLocal] = ngày hiện tại theo giờ công ty.</summary>
    public static string? Apply(User user, ProfileUpdateModel m, DateTime todayLocal)
    {
        string? fullName = null;
        if (m.FullName != null)
        {
            fullName = m.FullName.Trim();
            if (fullName.Length == 0) return "Họ và tên không được để trống";
            if (fullName.Length > MaxFullName) return $"Họ và tên tối đa {MaxFullName} ký tự";
        }

        string? phone = user.Phone;
        if (m.Phone != null)
        {
            if (m.Phone.Trim().Length == 0) phone = null;
            else
            {
                phone = NormalizePhone(m.Phone);
                if (phone == null) return "Số điện thoại không hợp lệ (ví dụ 0912345678)";
            }
        }

        DateTime? dob = user.DateOfBirth;
        if (m.DateOfBirth != null)
        {
            if (m.DateOfBirth.Trim().Length == 0) dob = null;
            else
            {
                if (!DateTime.TryParseExact(m.DateOfBirth.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var d))
                    return "Ngày sinh không hợp lệ (định dạng yyyy-MM-dd)";
                if (d.Date > todayLocal.Date) return "Ngày sinh không được ở tương lai";
                if (d.Year < 1900) return "Ngày sinh không hợp lệ";
                dob = d.Date;
            }
        }

        string? address = user.Address;
        if (m.Address != null)
        {
            var a = m.Address.Trim();
            if (a.Length > MaxAddress) return $"Địa chỉ tối đa {MaxAddress} ký tự";
            address = a.Length == 0 ? null : a;
        }

        // Mọi thứ hợp lệ mới ghi
        if (fullName != null) user.FullName = fullName;
        user.Phone = phone;
        user.DateOfBirth = dob;
        user.Address = address;
        return null;
    }
}
