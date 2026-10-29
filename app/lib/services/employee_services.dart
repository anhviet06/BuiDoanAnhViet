import '../models/app_user.dart';
import '../models/attendance.dart';
import '../models/check_request.dart';
import '../models/monthly_report.dart';
import 'api_client.dart';

/// Chấm công của nhân viên: check-in/out, dashboard hôm nay, lịch sử, lương tạm tính.
class AttendanceService {
  final ApiClient _api;

  AttendanceService(this._api);

  /// Gửi check-in lên server. Ném ApiException (message của server) nếu bị từ chối
  /// (ngoài bán kính, ngoài giờ ca, QR sai, đã check-in, đang nghỉ phép...).
  Future<CheckResult> checkIn(CheckRequest request) => _check('/api/Attendances/check-in', request);

  Future<CheckResult> checkOut(CheckRequest request) => _check('/api/Attendances/check-out', request);

  Future<CheckResult> _check(String path, CheckRequest request) async {
    final data = await _api.post(path, data: request.toJson()) as Map<String, dynamic>;
    return CheckResult(
      (data['message'] ?? '') as String,
      Attendance.fromJson(data['attendance'] as Map<String, dynamic>),
    );
  }

  Future<TodayInfo> today() async => TodayInfo.fromJson(await _api.get('/api/Attendances/today') as Map<String, dynamic>);

  /// Lịch sử chấm công của chính mình trong khoảng ngày làm việc [from, to].
  Future<List<Attendance>> history({required DateTime from, required DateTime to}) async {
    final data = await _api.get('/api/Attendances', query: {'from': _day(from), 'to': _day(to)}) as List;
    return data.map((e) => Attendance.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lương tạm tính + thống kê của chính mình trong tháng [month] (chỉ năm/tháng được dùng).
  Future<MonthlySummary> myMonthly(DateTime month) async {
    final data = await _api.get('/api/Reports/my-monthly', query: {'month': monthKey(month)}) as Map<String, dynamic>;
    final rows = data['rows'] as List;
    return rows.isEmpty ? const MonthlySummary() : MonthlySummary.fromJson(rows.first as Map<String, dynamic>);
  }

  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
}

/// Hồ sơ của chính mình (/api/Users/me, /api/Users/change-password).
class ProfileService {
  final ApiClient _api;

  ProfileService(this._api);

  Future<AppUser> me() async => AppUser.fromJson(await _api.get('/api/Users/me') as Map<String, dynamic>);

  Future<void> updateName(String fullName) => _api.put('/api/Users/me', data: {'fullName': fullName});

  /// Ném ApiException 400 nếu mật khẩu hiện tại sai.
  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      _api.post('/api/Users/change-password', data: {'currentPassword': currentPassword, 'newPassword': newPassword});
}
