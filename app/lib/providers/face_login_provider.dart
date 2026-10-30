import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/device_id_service.dart';
import '../services/token_storage.dart';
import 'auth_provider.dart';

/// Hồ sơ "đăng nhập bằng khuôn mặt" lưu trên máy: ai đã bật + token thiết bị do server cấp.
/// TRUNG THỰC: khuôn mặt chỉ để xác nhận người sống trên thiết bị đã đăng ký bằng OTP, KHÔNG nhận diện danh tính;
/// độ an toàn dựa vào token theo thiết bị (30 ngày, thu hồi được).
class FaceLoginProfile {
  final int userId;
  final String fullName;
  final String deviceToken;

  const FaceLoginProfile({required this.userId, required this.fullName, required this.deviceToken});

  Map<String, dynamic> toJson() => {'userId': userId, 'fullName': fullName, 'deviceToken': deviceToken};

  static FaceLoginProfile? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final token = m['deviceToken'] as String?;
      final id = m['userId'] as int?;
      if (token == null || token.isEmpty || id == null) return null;
      return FaceLoginProfile(userId: id, fullName: (m['fullName'] ?? '') as String, deviceToken: token);
    } catch (_) {
      return null;
    }
  }
}

/// Quản lý đăng nhập bằng khuôn mặt (token thiết bị) trên máy này.
/// Đăng xuất thường KHÔNG xóa hồ sơ (lần sau vào bằng mặt); "Đổi tài khoản"/"Tắt" thì thu hồi + xóa.
class FaceLoginProvider extends ChangeNotifier {
  static const profileKey = 'face_login';
  static const promptCountKey = 'face_prompt_count';
  static const maxPrompts = 2;
  static const maxFailures = 3;

  static const expiredMessage = 'Phiên đăng nhập bằng khuôn mặt đã hết hạn hoặc bị thu hồi. Hãy đăng nhập bằng mật khẩu và OTP.';

  final TokenStorage _storage;
  final AuthService _service;
  final AuthProvider _auth;
  final DeviceIdService _device;

  FaceLoginProfile? profile;
  bool loaded = false;
  Future<void>? _loading;

  FaceLoginProvider(this._storage, this._service, this._auth, this._device);

  bool get enabled => profile != null;

  /// Hồ sơ đang bật cho đúng tài khoản đang đăng nhập (dùng cho công tắc ở Cài đặt).
  bool get enabledForCurrentUser => profile != null && profile!.userId == _auth.session?.userId;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    profile = FaceLoginProfile.tryParse(await _storage.readValue(profileKey));
    loaded = true;
    notifyListeners();
  }

  /// Có nên hỏi "Bật đăng nhập bằng khuôn mặt?" sau lần đăng nhập mật khẩu này (chưa bật và mới hỏi dưới 2 lần).
  Future<bool> shouldPrompt() async {
    await ensureLoaded();
    if (enabled) return false;
    return await _promptCount() < maxPrompts;
  }

  Future<int> _promptCount() async => int.tryParse(await _storage.readValue(promptCountKey) ?? '') ?? 0;

  /// Người dùng chọn "Để sau": tăng số lần đã hỏi.
  Future<void> postponePrompt() async => _storage.writeValue(promptCountKey, '${await _promptCount() + 1}');

  /// Bật cho tài khoản đang đăng nhập: xin token thiết bị rồi lưu cục bộ. Gọi SAU khi qua bước xác nhận người sống.
  Future<void> enable() async {
    final session = _auth.session;
    if (session == null) throw StateError('Chưa đăng nhập');
    final old = profile;
    final deviceId = await _device.get();
    final token = await _service.issueDeviceToken(deviceId);
    if (old != null && old.userId != session.userId) {
      // Máy này đang gắn với tài khoản khác: thu hồi token cũ (tốt nhất có thể)
      try {
        await _service.revokeDeviceToken(deviceId, old.deviceToken);
      } catch (_) {}
    }
    profile = FaceLoginProfile(userId: session.userId, fullName: session.fullName, deviceToken: token);
    await _storage.writeValue(profileKey, jsonEncode(profile!.toJson()));
    notifyListeners();
  }

  /// Tắt / đổi tài khoản: thu hồi token trên server (nếu được) rồi xóa hồ sơ cục bộ.
  Future<void> disable() async {
    final p = profile;
    if (p == null) return;
    try {
      await _service.revokeDeviceToken(await _device.get(), p.deviceToken);
    } catch (_) {
      // Không có mạng thì vẫn xóa cục bộ; token tự hết hạn sau 30 ngày
    }
    await clearLocal();
  }

  Future<void> clearLocal() async {
    profile = null;
    await _storage.deleteValue(profileKey);
    notifyListeners();
  }

  /// Đăng nhập bằng token thiết bị (gọi SAU khi người dùng qua bước xác nhận người sống).
  /// Trả null nếu thành công, ngược lại là thông báo lỗi. 401 (sai/hết hạn/thu hồi/khóa) -> xóa hồ sơ cục bộ.
  Future<String?> loginWithFace() async {
    final p = profile;
    if (p == null) return expiredMessage;
    try {
      final result = await _service.deviceLogin(await _device.get(), p.deviceToken);
      await _auth.acceptLogin(result);
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await clearLocal();
        return expiredMessage;
      }
      return e.message;
    } catch (_) {
      return 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';
    }
  }
}
