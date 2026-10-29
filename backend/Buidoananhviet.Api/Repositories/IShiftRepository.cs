using Buidoananhviet.Api.Models;

namespace Buidoananhviet.Api.Repositories;

public interface IShiftRepository
{
    Task<IEnumerable<Shift>> GetShiftsAsync();
    Task<Shift?> GetShiftByIdAsync(int id);
    Task AddShiftAsync(Shift entity);
    Task UpdateShiftAsync(Shift entity);
    Task DeleteShiftAsync(int id);
    Task<Shift?> GetShiftByQrTokenAsync(string qrToken);
}
