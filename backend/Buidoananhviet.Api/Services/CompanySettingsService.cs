using System.Globalization;
using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;

namespace Buidoananhviet.Api.Services;

// Đọc cấu hình công ty từ bảng Settings (key/value)
public interface ICompanySettingsService
{
    Task<CompanySettingsModel> GetAsync();
}

public class CompanySettingsService : ICompanySettingsService
{
    private readonly ISettingRepository _settingRepository;

    public CompanySettingsService(ISettingRepository settingRepository)
    {
        _settingRepository = settingRepository;
    }

    public async Task<CompanySettingsModel> GetAsync()
    {
        var settings = (await _settingRepository.GetSettingsAsync()).ToDictionary(s => s.Key, s => s.Value);
        return new CompanySettingsModel
        {
            Latitude = Read(settings, SettingKeys.CompanyLat),
            Longitude = Read(settings, SettingKeys.CompanyLng),
            RadiusMeters = Read(settings, SettingKeys.RadiusMeters),
            LatePenaltyPerMinute = (decimal)Read(settings, SettingKeys.LatePenaltyPerMinute)
        };
    }

    private static double Read(Dictionary<string, string> settings, string key) =>
        settings.TryGetValue(key, out var v) && double.TryParse(v, NumberStyles.Float, CultureInfo.InvariantCulture, out var d)
            ? d
            : 0;
}
