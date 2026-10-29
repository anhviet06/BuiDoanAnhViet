using Buidoananhviet.Api.Models;

namespace Buidoananhviet.Api.Repositories;

public interface IUserRepository
{
    Task<IEnumerable<User>> GetUsersAsync();
    Task<User?> GetUserByIdAsync(int id);
    Task AddUserAsync(User entity);
    Task UpdateUserAsync(User entity);
    Task DeleteUserAsync(int id);
    /// <summary>Tìm theo email hoặc username (không phân biệt hoa thường).</summary>
    Task<User?> GetUserByLoginAsync(string emailOrUsername);
    Task<bool> ExistsAsync(string email, string username, int? excludeId = null);
}
