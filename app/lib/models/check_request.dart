import 'attendance.dart';

/// Dữ liệu gửi lên khi check-in / check-out (sau khi vân tay -> GPS -> quét QR).
class CheckRequest {
  final String qrToken;
  final double latitude;
  final double longitude;
  final bool isMocked;
  final String deviceId;

  /// Đã qua thử thách khuôn mặt (liveness). false = bỏ qua khi demo (server chỉ hiện nhãn, không đánh dấu nghi ngờ).
  final bool faceVerified;

  const CheckRequest({
    required this.qrToken,
    required this.latitude,
    required this.longitude,
    required this.isMocked,
    required this.deviceId,
    this.faceVerified = false,
  });

  Map<String, dynamic> toJson() => {
        'qrToken': qrToken,
        'latitude': latitude,
        'longitude': longitude,
        'isMocked': isMocked,
        'deviceId': deviceId,
        'faceVerified': faceVerified,
      };
}

/// Kết quả chấm công thành công: lời nhắn của server + bản ghi.
class CheckResult {
  final String message;
  final Attendance attendance;

  const CheckResult(this.message, this.attendance);
}
