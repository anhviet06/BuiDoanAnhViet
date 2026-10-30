using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace Buidoananhviet.Api.Models;

public class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Shift> Shifts => Set<Shift>();
    public DbSet<Attendance> Attendances => Set<Attendance>();
    public DbSet<Leave> Leaves => Set<Leave>();
    public DbSet<Setting> Settings => Set<Setting>();
    public DbSet<DeviceLogin> DeviceLogins => Set<DeviceLogin>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        ApplyUtcKind(b);
        b.Entity<User>(e =>
        {
            e.HasIndex(x => x.Email).IsUnique();
            e.HasIndex(x => x.Username).IsUnique();
            e.Property(x => x.HourlyRate).HasPrecision(18, 2);
            e.Property(x => x.Phone).HasMaxLength(20);
            e.Property(x => x.Address).HasMaxLength(200);
            e.Property(x => x.DateOfBirth).HasColumnType("date");
        });
        b.Entity<Shift>().HasIndex(x => x.QrToken).IsUnique();
        b.Entity<DeviceLogin>(e =>
        {
            e.Property(x => x.DeviceId).HasMaxLength(200);
            e.Property(x => x.TokenHash).HasMaxLength(64);
            e.HasIndex(x => x.TokenHash).IsUnique();
            e.HasIndex(x => new { x.UserId, x.DeviceId });
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });
        b.Entity<Setting>().HasIndex(x => x.Key).IsUnique();
        b.Entity<Attendance>(e =>
        {
            e.Property(x => x.WorkedHours).HasPrecision(18, 2);
            e.Property(x => x.LatePenalty).HasPrecision(18, 2);
            e.Property(x => x.Pay).HasPrecision(18, 2);
            e.Property(x => x.GrossPay).HasPrecision(18, 2);
            e.Property(x => x.WorkDate).HasColumnType("date");
            // Mỗi nhân viên chỉ chấm công 1 lần/ca/ngày
            e.HasIndex(x => new { x.UserId, x.ShiftId, x.WorkDate }).IsUnique();
            e.HasIndex(x => new { x.DeviceId, x.WorkDate });
            e.HasIndex(x => new { x.UserId, x.CheckInAt });
        });
    }

    // SQL Server trả DateTime kiểu Unspecified -> JSON mất hậu tố "Z". Các cột lưu giờ UTC
    // được đánh dấu Kind=Utc khi đọc ra để client biết đó là UTC (không đổi schema).
    private static void ApplyUtcKind(ModelBuilder b)
    {
        var utc = new ValueConverter<DateTime, DateTime>(v => v, v => DateTime.SpecifyKind(v, DateTimeKind.Utc));
        var utcNullable = new ValueConverter<DateTime?, DateTime?>(
            v => v, v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : v);
        b.Entity<User>().Property(x => x.CreatedAt).HasConversion(utc);
        b.Entity<User>().Property(x => x.OtpExpiresAt).HasConversion(utcNullable);
        b.Entity<Leave>().Property(x => x.CreatedAt).HasConversion(utc);
        b.Entity<Attendance>().Property(x => x.CheckInAt).HasConversion(utc);
        b.Entity<Attendance>().Property(x => x.CheckOutAt).HasConversion(utcNullable);
        b.Entity<DeviceLogin>().Property(x => x.CreatedAt).HasConversion(utc);
        b.Entity<DeviceLogin>().Property(x => x.ExpiresAt).HasConversion(utc);
        b.Entity<DeviceLogin>().Property(x => x.LastUsedAt).HasConversion(utcNullable);
        b.Entity<DeviceLogin>().Property(x => x.RevokedAt).HasConversion(utcNullable);
    }
}
