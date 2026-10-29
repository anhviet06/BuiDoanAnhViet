using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Buidoananhviet.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;

namespace Buidoananhviet.Api.Tests;

/// <summary>Môi trường test: DB InMemory + 5 ca cố định + đồng hồ giả lập (giờ địa phương UTC+7).</summary>
public sealed class TestEnv : IDisposable
{
    public static readonly TimeSpan Offset = TimeSpan.FromHours(7);
    public ApplicationDbContext Db { get; }
    public SimulatedClock Clock { get; }
    public AttendanceService Svc { get; }
    public IConfiguration Cfg { get; }
    public User Admin { get; private set; } = null!;

    public TestEnv(DateTime? nowLocal = null)
    {
        var opts = new DbContextOptionsBuilder<ApplicationDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        Db = new ApplicationDbContext(opts);
        Cfg = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Time:UtcOffsetHours"] = "7",
            ["Attendance:EarlyCheckInMinutes"] = "30",
            ["Seed:EmployeePassword"] = "Test@12345",
            ["Seed:EmailBase"] = "someone@gmail.com",
        }).Build();
        Clock = new SimulatedClock(Offset, nowLocal ?? new DateTime(2026, 10, 29, 9, 0, 0));
        Svc = new AttendanceService(new UserRepository(Db), new ShiftRepository(Db), new AttendanceRepository(Db),
            new LeaveRepository(Db), new CompanySettingsService(new SettingRepository(Db)), Clock, Cfg);
    }

    public static async Task<TestEnv> CreateAsync(DateTime? nowLocal = null, bool withAdmin = true)
    {
        var env = new TestEnv(nowLocal);
        await DbSeeder.EnsureSettingsAsync(env.Db);
        await DbSeeder.SyncShiftsAsync(env.Db, NullLogger.Instance, forceDefinition: true);
        if (withAdmin)
        {
            env.Admin = new User { Email = "admin@timeguard.local", Username = "admin", FullName = "Quản trị viên", Role = Roles.Admin, PasswordHash = "x" };
            env.Db.Users.Add(env.Admin);
            await env.Db.SaveChangesAsync();
        }
        return env;
    }

    public async Task<User> AddEmployeeAsync(string username, decimal rate = 30000)
    {
        var u = new User { Email = username + "@test.local", Username = username, FullName = username, Role = Roles.Employee, HourlyRate = rate, PasswordHash = "x" };
        Db.Users.Add(u);
        await Db.SaveChangesAsync();
        return u;
    }

    public string Token(string shiftName) => FixedShifts.Get(shiftName).QrToken;

    public static CheckRequestModel Req(string token, string device = "dev-1", bool mocked = false) => new()
    {
        QrToken = token, Latitude = 10.7769, Longitude = 106.7009, DeviceId = device, IsMocked = mocked, FaceVerified = true
    };

    public Task<AttendanceResult> CheckIn(User u, string shift, DateTime at, string device = "dev-1")
    {
        Clock.LocalNow = at;
        return Svc.CheckInAsync(u.Id, Req(Token(shift), device));
    }

    public Task<AttendanceResult> CheckOut(User u, string shift, DateTime at, string device = "dev-1")
    {
        Clock.LocalNow = at;
        return Svc.CheckOutAsync(u.Id, Req(Token(shift), device));
    }

    public void Dispose() => Db.Dispose();
}
