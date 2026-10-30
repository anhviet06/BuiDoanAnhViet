using System.Text;
using Buidoananhviet.Api.Models;
using Buidoananhviet.Api.Repositories;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Buidoananhviet.Api.Services;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;

var builder = WebApplication.CreateBuilder(args);

// Chạy lệnh quản trị (--reset-demo...) thì chỉ in kết quả gọn, không in log câu lệnh SQL của EF Core
if (AdminCommands.IsCommand(args))
    builder.Logging.AddFilter("Microsoft.EntityFrameworkCore", LogLevel.Warning);

// Lắng nghe mọi địa chỉ để máy ảo Android truy cập qua 10.0.2.2:5000
builder.WebHost.UseUrls(builder.Configuration["Urls"] ?? "http://0.0.0.0:5000");

// ===== Chọn database provider ở MỘT chỗ duy nhất =====
// Cùng provider với project mẫu: SQL Server (LocalDB). Đổi provider/chuỗi kết nối chỉ ở đây.
builder.Services.AddDbContext<ApplicationDbContext>(opt =>
    opt.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IShiftRepository, ShiftRepository>();
builder.Services.AddScoped<IAttendanceRepository, AttendanceRepository>();
builder.Services.AddScoped<ILeaveRepository, LeaveRepository>();
builder.Services.AddScoped<ISettingRepository, SettingRepository>();
builder.Services.AddScoped<IEmailSender, EmailSender>();
builder.Services.AddSingleton<ITimeService, TimeService>();
builder.Services.AddScoped<ICompanySettingsService, CompanySettingsService>();
builder.Services.AddScoped<IAttendanceService, AttendanceService>();
builder.Services.AddScoped<IReportService, ReportService>();
builder.Services.AddScoped<IDeviceLoginService, DeviceLoginService>();

// JWT: secret lấy từ cấu hình/biến môi trường
var jwtKey = builder.Configuration["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey) || jwtKey.Length < 32)
    throw new InvalidOperationException("Jwt:Key chưa cấu hình hoặc ngắn hơn 32 ký tự (xem appsettings.Example.json).");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidAudience = builder.Configuration["Jwt:Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
    });
builder.Services.AddAuthorization();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
{
    // Nút Authorize (Bearer JWT) trên Swagger
    o.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Dán JWT nhận được từ verify-otp"
    });
    o.AddSecurityRequirement(doc => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", doc)] = new List<string>()
    });
});

var app = builder.Build();

// Lệnh quản trị (--reset-demo, --make-admin, --make-employee): chạy xong rồi thoát, KHÔNG mở web host
if (AdminCommands.IsCommand(args))
{
    using var cmdScope = app.Services.CreateScope();
    var cmdDb = cmdScope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await cmdDb.Database.MigrateAsync();
    return await AdminCommands.RunAsync(args, cmdDb, app.Configuration, app.Logger, app.Environment.IsDevelopment());
}

// Tự áp dụng migration + đồng bộ cấu hình công ty và 5 ca cố định khi khởi động (KHÔNG tạo user nào)
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await db.Database.MigrateAsync();
    await DbSeeder.SeedAsync(db, app.Configuration, app.Logger);
}

app.UseSwagger();
app.UseSwaggerUI();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/", () => Results.Redirect("/swagger"));

app.Run();
return 0;

