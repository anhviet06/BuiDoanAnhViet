import '../core/jwt_utils.dart';

/// Phiên đăng nhập hiện tại, dựng từ JWT (+ họ tên lưu kèm lúc đăng nhập).
class AuthSession {
  final String token;
  final int userId;
  final String username;
  final String email;
  final String fullName;
  final String role; // 'admin' | 'employee'

  const AuthSession({
    required this.token,
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  /// Dựng từ token đã lưu; trả null nếu token hỏng/hết hạn/không có role hợp lệ.
  static AuthSession? fromToken(String token, {String? fullName}) {
    if (JwtUtils.isExpired(token)) return null;
    final claims = JwtUtils.decode(token);
    if (claims == null) return null;
    final role = claims['role'];
    if (role != 'admin' && role != 'employee') return null;
    final username = (claims['unique_name'] ?? '').toString();
    return AuthSession(
      token: token,
      userId: int.tryParse((claims['nameid'] ?? '').toString()) ?? 0,
      username: username,
      email: (claims['email'] ?? '').toString(),
      fullName: (fullName == null || fullName.isEmpty) ? username : fullName,
      role: role as String,
    );
  }
}
