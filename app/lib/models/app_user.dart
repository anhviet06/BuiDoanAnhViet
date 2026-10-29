/// Người dùng (nhân viên hoặc admin) do backend trả về. Không có mật khẩu/OTP.
class AppUser {
  final int id;
  final String email;
  final String username;
  final String fullName;
  final String role; // 'admin' | 'employee'
  final double hourlyRate;
  final bool isLocked;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.hourlyRate,
    required this.isLocked,
    this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        email: (json['email'] ?? '') as String,
        username: (json['username'] ?? '') as String,
        fullName: (json['fullName'] ?? '') as String,
        role: (json['role'] ?? 'employee') as String,
        hourlyRate: ((json['hourlyRate'] ?? 0) as num).toDouble(),
        isLocked: (json['isLocked'] ?? false) as bool,
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
      );
}
