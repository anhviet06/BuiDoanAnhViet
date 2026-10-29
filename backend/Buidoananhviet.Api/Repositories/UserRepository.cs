using Buidoananhviet.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Buidoananhviet.Api.Repositories;

public class UserRepository : IUserRepository
{
    private readonly ApplicationDbContext _context;

    public UserRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IEnumerable<User>> GetUsersAsync()
    {
        return await _context.Users.OrderBy(x => x.Id).ToListAsync();
    }

    public async Task<User?> GetUserByIdAsync(int id)
    {
        return await _context.Users.FindAsync(id);
    }

    public async Task AddUserAsync(User entity)
    {
        _context.Users.Add(entity);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateUserAsync(User entity)
    {
        _context.Entry(entity).State = EntityState.Modified;
        await _context.SaveChangesAsync();
    }

    public async Task DeleteUserAsync(int id)
    {
        var entity = await _context.Users.FindAsync(id);
        if (entity != null)
        {
            _context.Users.Remove(entity);
            await _context.SaveChangesAsync();
        }
    }

    public async Task<User?> GetUserByLoginAsync(string emailOrUsername)
    {
        var key = emailOrUsername.Trim().ToLower();
        return await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == key || u.Username.ToLower() == key);
    }

    public async Task<bool> ExistsAsync(string email, string username, int? excludeId = null)
    {
        var e = email.Trim().ToLower();
        var u = username.Trim().ToLower();
        return await _context.Users.AnyAsync(x => x.Id != excludeId && (x.Email.ToLower() == e || x.Username.ToLower() == u));
    }
}
