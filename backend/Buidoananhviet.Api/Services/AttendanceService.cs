using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Services;

public record AttendanceResult(bool Success, int StatusCode, string Message, Attendance? Attendance = null);

public interface IAttendanceService
{
    Task<AttendanceResult> CheckInAsync(int userId, CheckRequestModel model);
    Task<AttendanceResult> CheckOutAsync(int userId, CheckRequestModel model);
    /// <summary>Admin gỡ cờ nghi ngờ của một bản ghi.</summary>
    Task<AttendanceResult> ReviewAsync(int id, int adminId, string? note);
    /// <summary>Admin đóng bản ghi quên check-out với giờ ra (giờ địa phương) do admin nhập.</summary>
    Task<AttendanceResult> CloseAsync(int id, int adminId, TimeSpan checkOutLocalTime, string? note);
}

// Nghiệp vụ chấm công: kiểm tra QR -> giờ ca -> nghỉ phép -> khoảng cách (Haversine) -> cờ gian lận.
public class AttendanceService : IAttendanceService
{
    private readonly IUserRepository _users;
    private readonly IShiftRepository _shifts;
    private readonly IAttendanceRepository _attendances;
    private readonly ILeaveRepository _leaves;
    private readonly ICompanySettingsService _company;
    private readonly ITimeService _time;
    private readonly TimeSpan _earlyCheckIn;

    public AttendanceService(
        IUserRepository users,
        IShiftRepository shifts,
        IAttendanceRepository attendances,
        ILeaveRepository leaves,
        ICompanySettingsService company,
        ITimeService time,
        IConfiguration configuration)
    {
        _users = users;
        _shifts = shifts;
        _attendances = attendances;
        _leaves = leaves;
        _company = company;
        _time = time;
        _earlyCheckIn = TimeSpan.FromMinutes(configuration.GetValue("Attendance:EarlyCheckInMinutes", 30));
    }

    private static AttendanceResult Fail(int status, string message) => new(false, status, message);

    public async Task<AttendanceResult> CheckInAsync(int userId, CheckRequestModel m)
    {
        var user = await _users.GetUserByIdAsync(userId);
        if (user == null) return Fail(401, "Tài khoản không tồn tại");
        if (user.IsLocked) return Fail(403, "Tài khoản đã bị khóa");

        var shift = await _shifts.GetShiftByQrTokenAsync(m.QrToken.Trim());
        if (shift == null || !shift.IsActive)
            return Fail(400, "Mã QR không hợp lệ hoặc ca không còn hoạt động");

        var nowLocal = _time.LocalNow;
        var today = nowLocal.Date;
        var shiftStart = today + shift.StartTime;
        var shiftEnd = today + shift.EndTime;

        if (nowLocal < shiftStart - _earlyCheckIn)
            return Fail(400, $"Chưa tới giờ check-in (mở trước giờ ca {(int)_earlyCheckIn.TotalMinutes} phút)");
        if (nowLocal > shiftEnd)
            return Fail(400, "Ca làm việc đã kết thúc");

        if (await _leaves.HasApprovedLeaveOnAsync(userId, today))
            return Fail(400, "Hôm nay bạn có đơn nghỉ phép đã được duyệt, không thể chấm công");

        if (await _attendances.FindAsync(userId, shift.Id, today) != null)
            return Fail(409, "Bạn đã check-in ca này hôm nay");

        // Không chấm 2 ca cùng lúc: đang có ca chưa check-out mà còn trong giờ thì phải check-out trước.
        // Ca đã quá giờ kết thúc mà quên check-out KHÔNG chặn (admin xử lý bằng "Đóng ca").
        var blocking = (await _attendances.GetOpenAttendancesAsync(userId))
            .Where(a => a.ShiftId != shift.Id && a.Shift != null && a.WorkDate.Date + a.Shift.EndTime > nowLocal)
            .OrderBy(a => a.CheckInAt).FirstOrDefault();
        if (blocking != null)
            return Fail(409, $"Bạn đang trong {blocking.Shift!.Name} chưa check-out. Hãy check-out ca đó trước khi chấm ca khác.");

        var company = await _company.GetAsync();
        if (company.RadiusMeters <= 0)
            return Fail(400, "Admin chưa cấu hình vị trí công ty");
        var distance = GeoCalculator.HaversineMeters(m.Latitude, m.Longitude, company.Latitude, company.Longitude);
        if (distance > company.RadiusMeters)
            return Fail(400, $"Bạn đang cách công ty {Math.Round(distance)} m, vượt bán kính cho phép {Math.Round(company.RadiusMeters)} m");

        // Đi trễ: chỉ tính khi quá thời gian ân hạn; khi đã trễ thì phạt tính từ giờ bắt đầu ca
        var minutesAfterStart = (int)Math.Floor((nowLocal - shiftStart).TotalMinutes);
        var isLate = minutesAfterStart > shift.LateGraceMinutes;
        var lateMinutes = isLate ? minutesAfterStart : 0;

        // Cờ gian lận -> suspicious
        var reasons = new List<string>();
        if (m.IsMocked)
            reasons.Add("GPS giả (mock location)");
        if (await _attendances.DeviceUsedByOtherAsync(m.DeviceId.Trim(), userId, today))
            reasons.Add("Thiết bị này đã chấm công cho nhân viên khác trong ngày");

        var attendance = new Attendance
        {
            UserId = userId,
            ShiftId = shift.Id,
            WorkDate = today,
            CheckInAt = _time.UtcNow,
            Latitude = m.Latitude,
            Longitude = m.Longitude,
            DistanceMeters = Math.Round(distance, 1),
            IsMockedLocation = m.IsMocked,
            DeviceId = m.DeviceId.Trim(),
            FaceVerified = m.FaceVerified,
            LateMinutes = lateMinutes,
            LatePenalty = lateMinutes * company.LatePenaltyPerMinute,
            Status = reasons.Count > 0 ? AttendanceStatus.Suspicious : isLate ? AttendanceStatus.Late : AttendanceStatus.OnTime,
            SuspiciousReason = reasons.Count > 0 ? string.Join("; ", reasons) : null
        };

        try
        {
            await _attendances.AddAttendanceAsync(attendance);
        }
        catch (DbUpdateException)
        {
            // Hai request đồng thời: unique index (User, Shift, WorkDate) chặn bản ghi thứ hai
            return Fail(409, "Bạn đã check-in ca này hôm nay");
        }

        attendance.Shift = shift;
        attendance.User = user;
        var message = attendance.Status switch
        {
            AttendanceStatus.Suspicious => "Check-in thành công nhưng bị đánh dấu nghi ngờ: " + attendance.SuspiciousReason,
            AttendanceStatus.Late => $"Check-in thành công, bạn đi trễ {lateMinutes} phút",
            _ => "Check-in thành công"
        };
        return new AttendanceResult(true, 200, message, attendance);
    }

    public async Task<AttendanceResult> CheckOutAsync(int userId, CheckRequestModel m)
    {
        var user = await _users.GetUserByIdAsync(userId);
        if (user == null) return Fail(401, "Tài khoản không tồn tại");
        if (user.IsLocked) return Fail(403, "Tài khoản đã bị khóa");

        var shift = await _shifts.GetShiftByQrTokenAsync(m.QrToken.Trim());
        if (shift == null)
            return Fail(400, "Mã QR không hợp lệ");

        var nowLocal = _time.LocalNow;
        var today = nowLocal.Date;

        var attendance = await _attendances.FindAsync(userId, shift.Id, today);
        // Ca qua nửa đêm (vd. Ca 3 18:00-24:00): check-out sau 00:00 thì bản ghi nằm ở ngày làm việc hôm trước
        if (attendance == null && ShiftTime.IsEndOfDay(shift.EndTime))
            attendance = await _attendances.FindOpenAsync(userId, shift.Id, today.AddDays(-1));
        if (attendance == null)
            return Fail(400, "Bạn chưa check-in ca này hôm nay");
        if (attendance.CheckOutAt != null)
            return Fail(409, "Bạn đã check-out ca này rồi");
        var workDay = attendance.WorkDate.Date;

        var company = await _company.GetAsync();
        if (company.RadiusMeters <= 0)
            return Fail(400, "Admin chưa cấu hình vị trí công ty");
        var distance = GeoCalculator.HaversineMeters(m.Latitude, m.Longitude, company.Latitude, company.Longitude);
        if (distance > company.RadiusMeters)
            return Fail(400, $"Bạn đang cách công ty {Math.Round(distance)} m, vượt bán kính cho phép {Math.Round(company.RadiusMeters)} m");

        // Số giờ làm = phút thực tế từ check-in đến check-out, giới hạn trong giờ ca
        var worked = ComputeWorkedHours(_time.ToLocal(attendance.CheckInAt), nowLocal, workDay + shift.StartTime, workDay + shift.EndTime);

        // Lương = giờ làm x lương giờ - phạt (không âm)
        var gross = Math.Round(worked * user.HourlyRate, 0, MidpointRounding.AwayFromZero);

        var reasons = new List<string>();
        if (m.IsMocked)
            reasons.Add("GPS giả khi check-out");
        if (!string.Equals(attendance.DeviceId, m.DeviceId.Trim(), StringComparison.Ordinal))
            reasons.Add("Check-out từ thiết bị khác với lúc check-in");

        attendance.CheckOutAt = _time.UtcNow;
        attendance.CheckOutLatitude = m.Latitude;
        attendance.CheckOutLongitude = m.Longitude;
        attendance.CheckOutDistanceMeters = Math.Round(distance, 1);
        attendance.CheckOutDeviceId = m.DeviceId.Trim();
        attendance.CheckOutFaceVerified = m.FaceVerified;
        attendance.WorkedHours = worked;
        attendance.GrossPay = gross;
        attendance.Pay = Math.Max(0, gross - attendance.LatePenalty);
        if (m.IsMocked) attendance.IsMockedLocation = true;
        if (reasons.Count > 0)
        {
            attendance.Status = AttendanceStatus.Suspicious;
            attendance.SuspiciousReason = string.Join("; ", new[] { attendance.SuspiciousReason }.Concat(reasons).Where(s => !string.IsNullOrEmpty(s)));
        }
        await _attendances.UpdateAttendanceAsync(attendance);

        attendance.User = user;
        var message = reasons.Count > 0
            ? "Check-out thành công nhưng bị đánh dấu nghi ngờ: " + string.Join("; ", reasons)
            : "Check-out thành công";
        return new AttendanceResult(true, 200, message, attendance);
    }

    public async Task<AttendanceResult> ReviewAsync(int id, int adminId, string? note)
    {
        var attendance = await _attendances.GetAttendanceDetailAsync(id);
        if (attendance == null) return Fail(404, "Không tìm thấy bản ghi chấm công");
        if (attendance.Status != AttendanceStatus.Suspicious)
            return Fail(409, "Bản ghi này không bị đánh dấu nghi ngờ");

        // Trả về trạng thái đúng theo số phút trễ; giữ SuspiciousReason để còn lịch sử
        attendance.Status = attendance.LateMinutes > 0 ? AttendanceStatus.Late : AttendanceStatus.OnTime;
        MarkAdminAction(attendance, "reviewed", adminId, note);
        await _attendances.UpdateAttendanceAsync(attendance);
        return new AttendanceResult(true, 200, "Đã gỡ cờ nghi ngờ", attendance);
    }

    public async Task<AttendanceResult> CloseAsync(int id, int adminId, TimeSpan checkOutLocalTime, string? note)
    {
        var attendance = await _attendances.GetAttendanceDetailAsync(id);
        if (attendance == null) return Fail(404, "Không tìm thấy bản ghi chấm công");
        if (attendance.CheckOutAt != null) return Fail(409, "Bản ghi này đã check-out rồi");
        if (checkOutLocalTime < TimeSpan.Zero || checkOutLocalTime >= TimeSpan.FromDays(1))
            return Fail(400, "Giờ ra không hợp lệ");

        var shift = attendance.Shift!;
        var user = attendance.User!;
        var day = attendance.WorkDate.Date;
        var checkInLocal = _time.ToLocal(attendance.CheckInAt);
        var outLocal = day + checkOutLocalTime;
        if (outLocal < checkInLocal)
            return Fail(400, $"Giờ ra phải sau giờ vào ({checkInLocal:HH:mm})");
        if (outLocal > _time.LocalNow)
            return Fail(400, "Giờ ra không được ở tương lai");

        var worked = ComputeWorkedHours(checkInLocal, outLocal, day + shift.StartTime, day + shift.EndTime);
        var gross = Math.Round(worked * user.HourlyRate, 0, MidpointRounding.AwayFromZero);
        attendance.CheckOutAt = _time.ToUtc(outLocal);
        attendance.WorkedHours = worked;
        attendance.GrossPay = gross;
        attendance.Pay = Math.Max(0, gross - attendance.LatePenalty);
        MarkAdminAction(attendance, "closed", adminId, string.IsNullOrWhiteSpace(note) ? "Admin đóng ca quên check-out" : note);
        await _attendances.UpdateAttendanceAsync(attendance);
        return new AttendanceResult(true, 200, "Đã đóng ca", attendance);
    }

    private void MarkAdminAction(Attendance a, string action, int adminId, string? note)
    {
        a.AdminAction = action;
        a.AdminNote = string.IsNullOrWhiteSpace(note) ? null : note.Trim();
        a.AdminActionAt = _time.UtcNow;
        a.AdminActionByUserId = adminId;
    }

    // Số giờ làm = phút từ max(giờ vào, đầu ca) đến min(giờ ra, cuối ca), làm tròn 2 số
    private static decimal ComputeWorkedHours(DateTime checkInLocal, DateTime outLocal, DateTime shiftStart, DateTime shiftEnd)
    {
        var from = Max(checkInLocal, shiftStart);
        var to = Min(outLocal, shiftEnd);
        var minutes = Math.Max(0, (to - from).TotalMinutes);
        return Math.Round((decimal)minutes / 60m, 2);
    }

    private static DateTime Max(DateTime a, DateTime b) => a > b ? a : b;
    private static DateTime Min(DateTime a, DateTime b) => a < b ? a : b;
}
