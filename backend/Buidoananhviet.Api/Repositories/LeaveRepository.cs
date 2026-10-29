using Buidoananhviet.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Repositories;

public class LeaveRepository : ILeaveRepository
{
    private readonly ApplicationDbContext _context;

    public LeaveRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Leave>> GetLeavesAsync()
    {
        return await _context.Leaves.OrderBy(x => x.Id).ToListAsync();
    }

    public async Task<Leave?> GetLeaveByIdAsync(int id)
    {
        return await _context.Leaves.FindAsync(id);
    }

    public async Task AddLeaveAsync(Leave entity)
    {
        _context.Leaves.Add(entity);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateLeaveAsync(Leave entity)
    {
        _context.Entry(entity).State = EntityState.Modified;
        await _context.SaveChangesAsync();
    }

    public async Task DeleteLeaveAsync(int id)
    {
        var entity = await _context.Leaves.FindAsync(id);
        if (entity != null)
        {
            _context.Leaves.Remove(entity);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<IEnumerable<Leave>> GetLeavesAsync(int? userId, string? status)
    {
        var query = _context.Leaves.Include(l => l.User).AsQueryable();
        if (userId != null) query = query.Where(l => l.UserId == userId);
        if (!string.IsNullOrWhiteSpace(status)) query = query.Where(l => l.Status == status);
        return await query.OrderByDescending(l => l.CreatedAt).ToListAsync();
    }

    public async Task<bool> HasOverlapAsync(int userId, DateTime from, DateTime to, int? excludeId = null)
    {
        return await _context.Leaves.AnyAsync(l => l.UserId == userId && l.Id != excludeId
            && l.Status != LeaveStatus.Rejected && l.FromDate <= to && l.ToDate >= from);
    }

    public async Task<bool> HasApprovedLeaveOnAsync(int userId, DateTime date)
    {
        var d = date.Date;
        return await _context.Leaves.AnyAsync(l => l.UserId == userId && l.Status == LeaveStatus.Approved
            && l.FromDate <= d && l.ToDate >= d);
    }
}
