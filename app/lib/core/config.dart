import 'package:flutter/foundation.dart';

/// Cấu hình dùng chung. URL API chỉ đặt ở MỘT chỗ này.
class AppConfig {
  /// Địa chỉ API. Mặc định là bản đã deploy. Chạy với backend trên máy (máy ảo Android) thì ghi đè:
  /// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000` (10.0.2.2 = localhost của máy host).
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://buianhviet06-001-site1.ctempurl.com');
  static const String appName = 'TimeGuard';

  /// Cho phép nút "Bỏ qua (chỉ để demo)" ở bước xác thực khuôn mặt, kết quả gửi `faceVerified=false`
  /// (không bị đánh dấu nghi ngờ). Mặc định bật ở bản debug; bản release tắt. Ghi đè bằng
  /// `--dart-define=ALLOW_SKIP_FACE=true|false`.
  static const bool allowSkipFace = bool.fromEnvironment('ALLOW_SKIP_FACE', defaultValue: kDebugMode);

  /// Hướng góc quay đầu của ML Kit: true = headEulerAngleY DƯƠNG khi người dùng quay sang TRÁI của họ
  /// (ảnh camera trước không lật gương). Nếu thử trên thiết bị thấy quay trái/phải bị ngược thì đổi thành false.
  static const bool faceLeftIsPositiveYaw = true;

  /// Quét QR bằng camera trước (máy ảo chỉ có webcam làm camera trước). Điện thoại thật nên đặt false để dùng camera sau.
  static const bool qrUseFrontCamera = true;
}
