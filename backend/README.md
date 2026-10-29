# TimeGuard - Backend

ASP.NET Core Web API (.NET 10, Controller + Repository + Services), EF Core + SQL Server, JWT, đăng nhập 2 bước bằng OTP (email), Swagger.

- Swagger: https://buianhviet06-001-site1.ctempurl.com/swagger/index.html
- Kiểm tra sống: `GET /api/health`

## Chạy trên máy

1. Cần .NET SDK 10 và SQL Server LocalDB.
2. Sao chép `Buidoananhviet.Api/appsettings.Example.json` thành `appsettings.Development.json`, điền `Jwt:Key` (>= 32 ký tự), `Seed:EmployeePassword`, `Smtp` (Gmail, mật khẩu ứng dụng). Đặt `Otp:DevMode=true` để OTP hiện ngay trong response (dùng khi demo).
3. Chạy:
   ```powershell
   cd Buidoananhviet.Api
   dotnet run
   ```
   Tự tạo database, áp migration và 5 ca cố định. API nghe ở `http://localhost:5000`.

## Lệnh quản trị (chỉ môi trường Development)

```powershell
dotnet run -- --make-admin <email>     # nâng tài khoản đã đăng ký lên admin (đăng nhập lại sau khi đổi)
dotnet run -- --seed-demo              # nạp 5 nhân viên mẫu + lịch sử chấm công (DB chưa có dữ liệu)
dotnet run -- --reset-demo             # XÓA chấm công/nghỉ phép/user (trừ "admin") rồi nạp lại dữ liệu mẫu
```

## Test

```powershell
cd Buidoananhviet.Api.Tests
dotnet test        # 49 test (DB trong bộ nhớ)
```

## Quy tắc chính

- Mỗi ca có mã QR cố định; chấm công 1 lần/ca/ngày; đi trễ quá ân hạn bị phạt theo phút.
- Không chấm 2 ca cùng lúc (phải check-out ca đang mở trước khi vào ca khác).
- Ca 3 kết thúc 24:00 (lưu `23:59:59.9999999`).
