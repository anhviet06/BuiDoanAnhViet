using Buidoananhviet.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Repositories;

public class ShiftRepository : IShiftRepository
{
    private readonly ApplicationDbContext _context;

    public ShiftRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Shift>> GetShiftsAsync()
    {
        return await _context.Shifts.OrderBy(x => x.StartTime).ToListAsync();
    }

    public async Task<Shift?> GetShiftByIdAsync(int id)
    {
        return await _context.Shifts.FindAsync(id);
    }

    public async Task AddShiftAsync(Shift entity)
    {
        _context.Shifts.Add(entity);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateShiftAsync(Shift entity)
    {
        _context.Entry(entity).State = EntityState.Modified;
        await _context.SaveChangesAsync();
    }

    public async Task DeleteShiftAsync(int id)
    {
        var entity = await _context.Shifts.FindAsync(id);
        if (entity != null)
        {
            _context.Shifts.Remove(entity);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<Shift?> GetShiftByQrTokenAsync(string qrToken)
    {
        return await _context.Shifts.FirstOrDefaultAsync(s => s.QrToken == qrToken);
    }
}
