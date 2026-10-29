using System.Globalization;
using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Buidoananhviet.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Buidoananhviet.Api.Controllers;

// Đã đăng nhập là xem được cấu hình công ty; chỉ admin được sửa.
[Authorize]
[Route("api/[controller]")]
[ApiController]
public class SettingsController : ControllerBase
{
    private readonly ISettingRepository _settingRepository;
    private readonly ICompanySettingsService _companySettings;
    private readonly ILogger<SettingsController> _logger;

    public SettingsController(ISettingRepository settingRepository, ICompanySettingsService companySettings, ILogger<SettingsController> logger)
    {
        _settingRepository = settingRepository;
        _companySettings = companySettings;
        _logger = logger;
    }

    [HttpGet("company")]
    public async Task<IActionResult> GetCompany()
    {
        try
        {
            return Ok(await _companySettings.GetAsync());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "GetCompany lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    [Authorize(Roles = Roles.Admin)]
    [HttpPut("company")]
    public async Task<IActionResult> UpdateCompany([FromBody] CompanySettingsModel model)
    {
        try
        {
            await UpsertAsync(SettingKeys.CompanyLat, model.Latitude.ToString(CultureInfo.InvariantCulture));
            await UpsertAsync(SettingKeys.CompanyLng, model.Longitude.ToString(CultureInfo.InvariantCulture));
            await UpsertAsync(SettingKeys.RadiusMeters, model.RadiusMeters.ToString(CultureInfo.InvariantCulture));
            await UpsertAsync(SettingKeys.LatePenaltyPerMinute, model.LatePenaltyPerMinute.ToString(CultureInfo.InvariantCulture));
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "UpdateCompany lỗi");
            return StatusCode(500, "Internal server error");
        }
    }

    private async Task UpsertAsync(string key, string value)
    {
        var setting = await _settingRepository.GetSettingByKeyAsync(key);
        if (setting == null)
        {
            await _settingRepository.AddSettingAsync(new Setting { Key = key, Value = value });
        }
        else
        {
            setting.Value = value;
            await _settingRepository.UpdateSettingAsync(setting);
        }
    }
}
