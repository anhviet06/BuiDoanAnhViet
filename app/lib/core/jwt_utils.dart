import 'dart:convert';

/// Đọc payload JWT (KHÔNG xác thực chữ ký - việc đó do server làm), chỉ để lấy role/hạn dùng.
class JwtUtils {
  static Map<String, dynamic>? decode(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// Token hỏng hoặc không có `exp` coi như đã hết hạn.
  static bool isExpired(String token, {DateTime? now}) {
    final exp = decode(token)?['exp'];
    if (exp is! num) return true;
    final expiry = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    return !(now ?? DateTime.now().toUtc()).isBefore(expiry);
  }
}
