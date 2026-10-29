using Buidoananhviet.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Repositories;

public class SettingRepository : ISettingRepository
{
    private readonly ApplicationDbContext _context;

    public SettingRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<Setting>> GetSettingsAsync()
    {
        return await _context.Settings.OrderBy(x => x.Key).ToListAsync();
    }

    public async Task<Setting?> GetSettingByIdAsync(int id)
    {
        return await _context.Settings.FindAsync(id);
    }

    public async Task AddSettingAsync(Setting entity)
    {
        _context.Settings.Add(entity);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateSettingAsync(Setting entity)
    {
        _context.Entry(entity).State = EntityState.Modified;
        await _context.SaveChangesAsync();
    }

    public async Task DeleteSettingAsync(int id)
    {
        var entity = await _context.Settings.FindAsync(id);
        if (entity != null)
        {
            _context.Settings.Remove(entity);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<Setting?> GetSettingByKeyAsync(string key)
    {
        return await _context.Settings.FirstOrDefaultAsync(s => s.Key == key);
    }
}
