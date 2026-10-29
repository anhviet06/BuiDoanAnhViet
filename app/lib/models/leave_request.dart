import 'app_user.dart';

/// Đơn nghỉ phép. Ngày là ngày địa phương (server lưu 00:00, không đổi múi giờ).
class LeaveRequest {
  final int id;
  final int userId;
  final AppUser? user; // chỉ có khi admin xem danh sách
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status; // pending | approved | rejected
  final String? adminNote;
  final DateTime? createdAt;

  const LeaveRequest({
    required this.id,
    required this.userId,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    this.user,
    this.adminNote,
    this.createdAt,
  });

  bool get isPending => status == 'pending';

  /// Số ngày nghỉ (tính cả ngày đầu và cuối).
  int get days => toDate.difference(fromDate).inDays + 1;

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
        id: json['id'] as int,
        userId: json['userId'] as int,
        user: json['user'] == null ? null : AppUser.fromJson(json['user'] as Map<String, dynamic>),
        fromDate: DateTime.parse(json['fromDate'] as String),
        toDate: DateTime.parse(json['toDate'] as String),
        reason: (json['reason'] ?? '') as String,
        status: (json['status'] ?? 'pending') as String,
        adminNote: json['adminNote'] as String?,
        createdAt: json['createdAt'] == null ? null : DateTime.tryParse(json['createdAt'] as String),
      );
}
