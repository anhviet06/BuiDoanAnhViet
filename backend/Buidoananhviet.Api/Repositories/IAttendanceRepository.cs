using Buidoananhviet.Api.Models;

namespace Buidoananhviet.Api.Repositories;

public interface IAttendanceRepository
{
    Task<IEnumerable<Attendance>> GetAttendancesAsync();
    Task<Attendance?> GetAttendanceByIdAsync(int id);
    Task AddAttendanceAsync(Attendance entity);
    Task UpdateAttendanceAsync(Attendance entity);
    Task DeleteAttendanceAsync(int id);
    Task<bool> HasAttendanceForUserAsync(int userId);
    Task<bool> HasAttendanceForShiftAsync(int shiftId);
    /// <summary>Danh sách chấm công (kèm User, Shift) theo ngày làm việc [fromDate, toDate], mới nhất trước.</summary>
    Task<IEnumerable<Attendance>> GetAttendancesAsync(int? userId, DateTime? fromDate, DateTime? toDate, string? status);
    Task<Attendance?> GetAttendanceDetailAsync(int id);
    Task<Attendance?> FindAsync(int userId, int shiftId, DateTime workDate);
    /// <summary>Các bản ghi CHƯA check-out của nhân viên (kèm Shift).</summary>
    Task<List<Attendance>> GetOpenAttendancesAsync(int userId);
    /// <summary>Bản ghi chưa check-out mới nhất của nhân viên ở ca này (kèm Shift); workDateFrom = chỉ lấy từ ngày này trở đi.</summary>
    Task<Attendance?> FindOpenAsync(int userId, int shiftId, DateTime workDateFrom);
    /// <summary>Thiết bị này đã dùng chấm công cho NHÂN VIÊN KHÁC trong ngày chưa.</summary>
    Task<bool> DeviceUsedByOtherAsync(string deviceId, int userId, DateTime workDate);
}
