# TimeGuard - Ứng dụng chấm công nhân viên

Nhân viên **quét QR của ca -> lấy vị trí GPS -> xác thực khuôn mặt (camera trước)** để chấm công vào/ra ca.
Hệ thống tự tính giờ làm, phạt đi trễ, lương tạm tính; admin quản lý nhân viên, ca làm, nghỉ phép và xem báo cáo.

| Thư mục | Nội dung |
|---|---|
| [`app/`](app) | Ứng dụng Flutter (Android) |
| [`backend/`](backend) | ASP.NET Core Web API (.NET 10) + SQL Server |
| [`qr/`](qr) | Ảnh mã QR của 5 ca + script tạo |

**API đã deploy (Swagger):** https://buianhviet06-001-site1.ctempurl.com/swagger/index.html

Hướng dẫn chi tiết: [`HUONG_DAN_CHI_TIET.md`](HUONG_DAN_CHI_TIET.md).

## Cài đặt cá nhân, hồ sơ và đăng nhập bằng khuôn mặt (T14)
- **Cài đặt cá nhân** (lưu trên máy, theo tài khoản): cỡ chữ, sáng/tối, màu chủ đạo, tông nền, khôi phục mặc định.
- **Hồ sơ**: sửa họ tên, số điện thoại, ngày sinh, địa chỉ.
- **Đăng nhập bằng khuôn mặt**: lần đầu đăng nhập bằng mật khẩu + OTP email, sau đó có thể bật để lần sau vào bằng khuôn mặt.

> **Lưu ý trung thực:** bước khuôn mặt chỉ xác nhận có người sống trước camera, trên một thiết bị đã được đăng ký bằng OTP. Ứng dụng **không nhận diện danh tính**. Độ an toàn dựa vào token theo thiết bị (server chỉ lưu bản băm, hạn 30 ngày, bị thu hồi khi đổi mật khẩu hoặc khi admin khóa tài khoản).
