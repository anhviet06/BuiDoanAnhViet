namespace Buidoananhviet.Api.Models;

// Dạng trả về của bản ghi chấm công. Dùng projection (không trả entity) vì entity
// kéo theo Shift -> lộ QrToken cho nhân viên.
public static class AttendanceView
{
    public static object From(Attendance a) => new
    {
        a.Id,
        a.UserId,
        UserName = a.User?.FullName,
        a.ShiftId,
        ShiftName = a.Shift?.Name,
        ShiftStartTime = a.Shift?.StartTime,
        ShiftEndTime = a.Shift?.EndTime,
        a.WorkDate,
        a.CheckInAt,
        a.CheckOutAt,
        a.Latitude,
        a.Longitude,
        a.DistanceMeters,
        a.CheckOutLatitude,
        a.CheckOutLongitude,
        a.CheckOutDistanceMeters,
        a.Status,
        a.SuspiciousReason,
        a.IsMockedLocation,
        a.DeviceId,
        a.CheckOutDeviceId,
        a.FaceVerified,
        a.CheckOutFaceVerified,
        a.LateMinutes,
        a.WorkedHours,
        a.LatePenalty,
        a.GrossPay,
        a.Pay,
        a.AdminAction,
        a.AdminNote,
        a.AdminActionAt
    };
}
