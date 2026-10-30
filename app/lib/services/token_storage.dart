import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nơi lưu token đăng nhập. Tách interface để test không cần plugin thật.
abstract class TokenStorage {
  Future<String?> readToken();
  Future<void> saveToken(String token);
  Future<String?> readFullName();
  Future<void> saveFullName(String fullName);
  /// Mã thiết bị (UUID sinh một lần). KHÔNG bị xóa khi đăng xuất để cùng một máy luôn có cùng mã.
  Future<String?> readDeviceId();
  Future<void> saveDeviceId(String deviceId);

  /// Lưu/đọc/xóa một giá trị chuỗi theo khóa tùy ý (cài đặt cá nhân, token thiết bị...). `clear()` KHÔNG xóa các khóa này.
  Future<String?> readValue(String key);
  Future<void> writeValue(String key, String value);
  Future<void> deleteValue(String key);

  /// Xóa token + họ tên (giữ lại mã thiết bị).
  Future<void> clear();
}

/// Lưu bằng flutter_secure_storage (Keystore trên Android).
class SecureTokenStorage implements TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _nameKey = 'auth_full_name';
  static const _deviceKey = 'device_id';

  final FlutterSecureStorage _storage;

  SecureTokenStorage([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  @override
  Future<String?> readFullName() => _storage.read(key: _nameKey);

  @override
  Future<void> saveFullName(String fullName) => _storage.write(key: _nameKey, value: fullName);

  @override
  Future<String?> readDeviceId() => _storage.read(key: _deviceKey);

  @override
  Future<void> saveDeviceId(String deviceId) => _storage.write(key: _deviceKey, value: deviceId);

  @override
  Future<String?> readValue(String key) => _storage.read(key: key);

  @override
  Future<void> writeValue(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> deleteValue(String key) => _storage.delete(key: key);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _nameKey);
  }
}
