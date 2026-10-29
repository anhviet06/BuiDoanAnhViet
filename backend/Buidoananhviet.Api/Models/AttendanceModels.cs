using System.ComponentModel.DataAnnotations;

namespace Buidoananhviet.Api.Models;

// Dữ liệu app gửi lên khi check-in / check-out (sau khi vân tay -> GPS -> quét QR)
public class CheckRequestModel
{
    // Token đọc từ QR của ca (cũng xác định ca)
    [Required]
    public string QrToken { get; set; } = string.Empty;

    [Range(-90, 90)]
    public double Latitude { get; set; }

    [Range(-180, 180)]
    public double Longitude { get; set; }

    // Thiết bị báo vị trí là giả (geolocator isMocked)
    public bool IsMocked { get; set; }

    // Mã định danh thiết bị do app tạo/lấy
    [Required, MaxLength(200)]
    public string DeviceId { get; set; } = string.Empty;

    // App đã xác thực khuôn mặt (liveness) trên máy. Tùy chọn: thiếu = false.
    // false (vd. người dùng bỏ qua khi demo) KHÔNG làm bản ghi thành nghi ngờ, chỉ hiện nhãn "Chưa xác thực mặt".
    public bool FaceVerified { get; set; }
}

// Admin gỡ cờ nghi ngờ (ghi chú tùy chọn)
public class AdminNoteModel
{
    [MaxLength(500)]
    public string? Note { get; set; }
}

// Admin đóng ca quên check-out: nhập giờ ra (giờ địa phương, trong ngày làm việc)
public class CloseAttendanceModel
{
    [Required]
    public TimeSpan CheckOutTime { get; set; }

    [MaxLength(500)]
    public string? Note { get; set; }
}
