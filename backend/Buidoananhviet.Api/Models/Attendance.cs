namespace Buidoananhviet.Api.Models;

public static class AttendanceStatus
{
    public const string OnTime = "on-time";
    public const string Late = "late";
    public const string Suspicious = "suspicious";
}

public class Attendance
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User? User { get; set; }
    public int ShiftId { get; set; }
    public Shift? Shift { get; set; }
    public DateTime WorkDate { get; set; }           // Ngày làm việc (theo giờ địa phương, 00:00)
    public DateTime CheckInAt { get; set; }
    public DateTime? CheckOutAt { get; set; }
    public double Latitude { get; set; }             // Vị trí lúc check-in
    public double Longitude { get; set; }
    public double DistanceMeters { get; set; }       // Khoảng cách tới công ty (Haversine, server tính)
    public string Status { get; set; } = AttendanceStatus.OnTime;
    public string? SuspiciousReason { get; set; }
    public bool IsMockedLocation { get; set; }       // GPS giả do thiết bị báo
    public string? DeviceId { get; set; }
    public int LateMinutes { get; set; }
    public double? CheckOutLatitude { get; set; }
    public double? CheckOutLongitude { get; set; }
    public double? CheckOutDistanceMeters { get; set; }
    public string? CheckOutDeviceId { get; set; }
    public bool FaceVerified { get; set; }            // Đã qua thử thách khuôn mặt (liveness) lúc check-in
    public bool? CheckOutFaceVerified { get; set; }   // Tương tự lúc check-out (null = chưa check-out)
    public decimal WorkedHours { get; set; }
    public decimal LatePenalty { get; set; }         // Phạt đi trễ = số phút trễ x mức phạt/phút
    public decimal GrossPay { get; set; }            // WorkedHours x HourlyRate
    public decimal Pay { get; set; }                 // max(0, GrossPay - LatePenalty), tính khi check-out

    // Admin xử lý bản ghi: "reviewed" (gỡ cờ nghi ngờ) hoặc "closed" (đóng ca quên check-out)
    public string? AdminAction { get; set; }
    public string? AdminNote { get; set; }
    public DateTime? AdminActionAt { get; set; }
    public int? AdminActionByUserId { get; set; }
}
