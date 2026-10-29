using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Buidoananhviet.Api.Models;

/// <summary>
/// Giờ ca là TimeSpan (cột SQL <c>time</c>, tối đa 23:59:59.9999999). "24:00" (hết ngày) được lưu là
/// <see cref="EndOfDay"/> = 1 ngày - 1 tick (chênh 0,1 micro giây so với 24:00 thật) nên không cần đổi schema,
/// phép so sánh/tính giờ làm vẫn đúng (giờ làm làm tròn 2 số thập phân nên ra đúng 6,00 giờ cho 18:00-24:00).
/// </summary>
public static class ShiftTime
{
    public static readonly TimeSpan EndOfDay = TimeSpan.FromDays(1) - TimeSpan.FromTicks(1);

    /// <summary>Giờ kết thúc trùng hoặc gần hết ngày (>= 23:59:59) thì coi là 24:00.</summary>
    public static bool IsEndOfDay(TimeSpan t) => t >= TimeSpan.FromHours(24) - TimeSpan.FromSeconds(1);

    /// <summary>Định dạng "HH:mm" cho giờ ca; giờ hết ngày hiện "24:00".</summary>
    public static string Format(TimeSpan t) => IsEndOfDay(t) ? "24:00" : $"{(int)t.TotalHours:00}:{t.Minutes:00}";

    /// <summary>Đọc "HH:mm", "HH:mm:ss" hoặc "24:00" (= hết ngày).</summary>
    public static bool TryParse(string? text, out TimeSpan value)
    {
        value = default;
        if (string.IsNullOrWhiteSpace(text)) return false;
        text = text.Trim();
        if (text is "24:00" or "24:00:00")
        {
            value = EndOfDay;
            return true;
        }
        return TimeSpan.TryParse(text, CultureInfo.InvariantCulture, out value) && value >= TimeSpan.Zero && value < TimeSpan.FromDays(1);
    }
}

/// <summary>JSON: nhận thêm "24:00" cho giờ ca; ghi ra định dạng chuẩn của TimeSpan.</summary>
public class ShiftTimeJsonConverter : JsonConverter<TimeSpan>
{
    public override TimeSpan Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var text = reader.GetString();
        if (!ShiftTime.TryParse(text, out var value))
            throw new JsonException("Giờ ca không hợp lệ (dùng HH:mm, ví dụ 06:00 hoặc 24:00)");
        return value;
    }

    public override void Write(Utf8JsonWriter writer, TimeSpan value, JsonSerializerOptions options) =>
        writer.WriteStringValue(value.ToString("c", CultureInfo.InvariantCulture));
}

/// <summary>Một ca cố định của hệ thống (đồng bộ lúc khởi động theo TÊN). QR cố định, KHÔNG random mỗi lần chạy.</summary>
public record FixedShift(string Name, TimeSpan Start, TimeSpan End, string QrToken, string PngFile);

public static class FixedShifts
{
    public const string Ca1 = "Ca 1";
    public const string Ca2 = "Ca 2";
    public const string Ca3 = "Ca 3";
    public const string GaySang = "Ca gãy sáng";
    public const string GayChieu = "Ca gãy chiều";

    // Mã QR cố định (tạo một lần, ghi cứng): dạng TG-<CA>-<8 ký tự dễ đọc, không có 0/O/1/I/L>.
    // Đổi mã bằng nút "Đổi mã QR" của admin sẽ làm PNG cũ lỗi thời; khởi động lại backend KHÔNG đổi token.
    public static readonly IReadOnlyList<FixedShift> All = new[]
    {
        new FixedShift(Ca1, new TimeSpan(6, 0, 0), new TimeSpan(12, 0, 0), "TG-CA1-KJJ446CX", "QR_Ca1.png"),
        new FixedShift(Ca2, new TimeSpan(12, 0, 0), new TimeSpan(18, 0, 0), "TG-CA2-E7U48ZW8", "QR_Ca2.png"),
        new FixedShift(Ca3, new TimeSpan(18, 0, 0), ShiftTime.EndOfDay, "TG-CA3-TV5FDGX8", "QR_Ca3.png"),
        new FixedShift(GaySang, new TimeSpan(5, 0, 0), new TimeSpan(9, 0, 0), "TG-GAYS-ZGT7Q99U", "QR_Ca_gay_sang.png"),
        new FixedShift(GayChieu, new TimeSpan(16, 0, 0), new TimeSpan(20, 0, 0), "TG-GAYC-JSRSED2A", "QR_Ca_gay_chieu.png"),
    };

    public static FixedShift Get(string name) => All.First(s => s.Name == name);
}
