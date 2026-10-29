using Buidoananhviet.Api.Models;

namespace Buidoananhviet.Api.Repositories;

public interface ILeaveRepository
{
    Task<IEnumerable<Leave>> GetLeavesAsync();
    Task<Leave?> GetLeaveByIdAsync(int id);
    Task AddLeaveAsync(Leave entity);
    Task UpdateLeaveAsync(Leave entity);
    Task DeleteLeaveAsync(int id);
    /// <summary>Danh sách đơn nghỉ (kèm User), lọc theo nhân viên/trạng thái, mới nhất trước.</summary>
    Task<IEnumerable<Leave>> GetLeavesAsync(int? userId, string? status);
    /// <summary>Có đơn pending/approved khác của nhân viên trùng khoảng ngày không.</summary>
    Task<bool> HasOverlapAsync(int userId, DateTime from, DateTime to, int? excludeId = null);
    /// <summary>Ngày này nhân viên có đơn nghỉ đã duyệt không.</summary>
    Task<bool> HasApprovedLeaveOnAsync(int userId, DateTime date);
}
