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
