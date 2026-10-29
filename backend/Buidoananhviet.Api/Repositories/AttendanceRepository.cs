using Buidoananhviet.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Repositories;

public class AttendanceRepository : IAttendanceRepository
{
    private readonly ApplicationDbContext _context;

    public AttendanceRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Attendance>> GetAttendancesAsync()
    {
        return await _context.Attendances.OrderBy(x => x.Id).ToListAsync();
    }

    public async Task<Attendance?> GetAttendanceByIdAsync(int id)
    {
        return await _context.Attendances.FindAsync(id);
    }

    public async Task AddAttendanceAsync(Attendance entity)
    {
        _context.Attendances.Add(entity);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAttendanceAsync(Attendance entity)
    {
        _context.Entry(entity).State = EntityState.Modified;
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAttendanceAsync(int id)
    {
        var entity = await _context.Attendances.FindAsync(id);
        if (entity != null)
        {
            _context.Attendances.Remove(entity);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<bool> HasAttendanceForUserAsync(int userId)
    {
        return await _context.Attendances.AnyAsync(a => a.UserId == userId);
    }

    public async Task<bool> HasAttendanceForShiftAsync(int shiftId)
    {
        return await _context.Attendances.AnyAsync(a => a.ShiftId == shiftId);
    }

    public async Task<IEnumerable<Attendance>> GetAttendancesAsync(int? userId, DateTime? fromDate, DateTime? toDate, string? status)
    {
        var query = _context.Attendances.Include(a => a.User).Include(a => a.Shift).AsQueryable();
        if (userId != null) query = query.Where(a => a.UserId == userId);
        if (fromDate != null) query = query.Where(a => a.WorkDate >= fromDate.Value.Date);
        if (toDate != null) query = query.Where(a => a.WorkDate <= toDate.Value.Date);
        if (!string.IsNullOrWhiteSpace(status)) query = query.Where(a => a.Status == status);
        return await query.OrderByDescending(a => a.CheckInAt).ToListAsync();
    }

    public async Task<Attendance?> GetAttendanceDetailAsync(int id)
    {
        return await _context.Attendances.Include(a => a.User).Include(a => a.Shift).FirstOrDefaultAsync(a => a.Id == id);
    }

    public async Task<Attendance?> FindAsync(int userId, int shiftId, DateTime workDate)
    {
        var d = workDate.Date;
        return await _context.Attendances.Include(a => a.Shift)
            .FirstOrDefaultAsync(a => a.UserId == userId && a.ShiftId == shiftId && a.WorkDate == d);
    }

    public async Task<List<Attendance>> GetOpenAttendancesAsync(int userId)
    {
        return await _context.Attendances.Include(a => a.Shift)
            .Where(a => a.UserId == userId && a.CheckOutAt == null).ToListAsync();
    }

    public async Task<Attendance?> FindOpenAsync(int userId, int shiftId, DateTime workDateFrom)
    {
        var d = workDateFrom.Date;
        return await _context.Attendances.Include(a => a.Shift)
            .Where(a => a.UserId == userId && a.ShiftId == shiftId && a.CheckOutAt == null && a.WorkDate >= d)
            .OrderByDescending(a => a.WorkDate).FirstOrDefaultAsync();
    }

    public async Task<bool> DeviceUsedByOtherAsync(string deviceId, int userId, DateTime workDate)
    {
        var d = workDate.Date;
        return await _context.Attendances.AnyAsync(a => a.DeviceId == deviceId && a.UserId != userId && a.WorkDate == d);
    }
}
