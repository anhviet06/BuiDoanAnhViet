namespace Buidoananhviet.Api.Models;

// Cấu hình dạng key/value (vị trí công ty, bán kính, mức phạt...)
public class Setting
{
    public int Id { get; set; }
    public string Key { get; set; } = "";
    public string Value { get; set; } = "";
}

public static class SettingKeys
{
    public const string CompanyLat = "Company.Lat";
    public const string CompanyLng = "Company.Lng";
    public const string RadiusMeters = "Company.RadiusMeters";
    public const string LatePenaltyPerMinute = "Penalty.PerMinute";
}
