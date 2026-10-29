import 'dart:math';

import 'token_storage.dart';

/// Mã định danh thiết bị gửi kèm mỗi lần chấm công (server dùng để phát hiện một máy chấm công
/// cho nhiều người). Là UUID v4 sinh MỘT lần rồi lưu trong secure storage, giữ nguyên qua các lần đăng xuất.
class DeviceIdService {
  final TokenStorage _storage;
  final Random _random;

  DeviceIdService(this._storage, {Random? random}) : _random = random ?? Random.secure();

  Future<String> get() async {
    final existing = await _storage.readDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;
    final id = generate();
    await _storage.saveDeviceId(id);
    return id;
  }

  /// UUID v4: 32 hex, version = 4, variant = 10xx.
  String generate() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
