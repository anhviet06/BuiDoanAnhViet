using Buidoananhviet.Api.Models;

namespace Buidoananhviet.Api.Repositories;

public interface ISettingRepository
{
    Task<IEnumerable<Setting>> GetSettingsAsync();
    Task<Setting?> GetSettingByIdAsync(int id);
    Task AddSettingAsync(Setting entity);
    Task UpdateSettingAsync(Setting entity);
    Task DeleteSettingAsync(int id);
    Task<Setting?> GetSettingByKeyAsync(string key);
}
