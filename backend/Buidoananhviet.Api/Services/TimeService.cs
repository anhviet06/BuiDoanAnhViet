namespace Buidoananhviet.Api.Services;

// Giờ ca (08:00...) là giờ địa phương, còn DB lưu UTC -> cần múi giờ cố định.
// Cấu hình Time:UtcOffsetHours (mặc định 7 = Việt Nam).
public interface ITimeService
{
    DateTime UtcNow { get; }
    DateTime LocalNow { get; }
    DateTime ToLocal(DateTime utc);
    DateTime ToUtc(DateTime local);
}

public class TimeService : ITimeService
{
    private readonly TimeSpan _offset;

    public TimeService(IConfiguration configuration)
    {
        _offset = TimeSpan.FromHours(configuration.GetValue("Time:UtcOffsetHours", 7.0));
    }

    public DateTime UtcNow => DateTime.UtcNow;
    public DateTime LocalNow => DateTime.UtcNow + _offset;
    public DateTime ToLocal(DateTime utc) => DateTime.SpecifyKind(utc, DateTimeKind.Utc) + _offset;
    public DateTime ToUtc(DateTime local) => DateTime.SpecifyKind(local - _offset, DateTimeKind.Utc);
}
