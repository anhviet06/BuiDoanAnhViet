# TimeGuard - Ứng dụng Flutter

Ứng dụng chấm công (Material 3, tiếng Việt, sáng/tối). Android là chính.

- **Nhân viên:** Hôm nay, chấm công 3 bước (quét QR hoặc nhập mã -> GPS -> xác thực khuôn mặt), Lịch sử, Nghỉ phép, Hồ sơ.
- **Admin:** Nhân viên, Ca làm (mã QR), Nghỉ phép, Cấu hình, Báo cáo + quản lý chấm công.

Thư viện chính: `provider`, `dio`, `flutter_secure_storage`, `geolocator`, `mobile_scanner`, `qr_flutter`, `camera` + `google_mlkit_face_detection`, `fl_chart`.

## Chạy

```powershell
flutter pub get
flutter run                      # dùng API đã deploy
```

Mặc định app gọi `https://buianhviet06-001-site1.ctempurl.com`. Muốn dùng backend chạy trên máy (máy ảo Android):

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

Máy ảo cần camera trước (webcam) và vị trí giả: `adb emu geo fix 106.7009 10.7769`.

## Kiểm tra

```powershell
flutter analyze
flutter test        # 130 test
```
