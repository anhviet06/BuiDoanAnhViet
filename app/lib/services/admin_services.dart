import '../models/app_user.dart';
import '../models/attendance.dart';
import '../models/company_settings.dart';
import '../models/leave_request.dart';
import '../models/monthly_report.dart';
import '../models/shift.dart';
import 'api_client.dart';

/// Quản lý người dùng (/api/Users). Các thao tác ghi chỉ admin được phép.
class UserService {
  final ApiClient _api;

  UserService(this._api);

  Future<List<AppUser>> list() async {
    final data = await _api.get('/api/Users') as List;
    return data.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> create({
    required String email,
    required String username,
    required String password,
    required String fullName,
    required double hourlyRate,
    required String role,
  }) =>
      _api.post('/api/Users', data: {
        'email': email,
        'username': username,
        'password': password,
        'fullName': fullName,
        'hourlyRate': hourlyRate,
        'role': role,
      });

  Future<void> update(
    int id, {
    required String email,
    required String username,
    required String fullName,
    required double hourlyRate,
    required String role,
  }) =>
      _api.put('/api/Users/$id', data: {
        'email': email,
        'username': username,
        'fullName': fullName,
        'hourlyRate': hourlyRate,
        'role': role,
      });

  Future<void> setLocked(int id, bool locked) => _api.put('/api/Users/$id/lock', data: {'isLocked': locked});

  Future<void> resetPassword(int id, String newPassword) =>
      _api.put('/api/Users/$id/password', data: {'newPassword': newPassword});

  /// Ném ApiException 409 nếu nhân viên đã có dữ liệu chấm công.
  Future<void> delete(int id) => _api.delete('/api/Users/$id');
}

/// Ca làm việc (/api/Shifts).
class ShiftService {
  final ApiClient _api;

  ShiftService(this._api);

  Future<List<Shift>> list() async {
    final data = await _api.get('/api/Shifts') as List;
    return data.map((e) => Shift.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> _body(String name, String start, String end, int grace, bool active) =>
      {'name': name, 'startTime': start, 'endTime': end, 'lateGraceMinutes': grace, 'isActive': active};

  Future<void> create({
    required String name,
    required String startTime,
    required String endTime,
    required int lateGraceMinutes,
    required bool isActive,
  }) =>
      _api.post('/api/Shifts', data: _body(name, startTime, endTime, lateGraceMinutes, isActive));

  Future<void> update(
    int id, {
    required String name,
    required String startTime,
    required String endTime,
    required int lateGraceMinutes,
    required bool isActive,
  }) =>
      _api.put('/api/Shifts/$id', data: _body(name, startTime, endTime, lateGraceMinutes, isActive));

  /// Ném ApiException 409 nếu ca đã có chấm công.
  Future<void> delete(int id) => _api.delete('/api/Shifts/$id');

  /// Tạo token QR mới (QR cũ hết hiệu lực), trả ca đã cập nhật.
  Future<Shift> regenerateQr(int id) async {
    final data = await _api.post('/api/Shifts/$id/regenerate-qr');
    return Shift.fromJson(data as Map<String, dynamic>);
  }
}

/// Cấu hình công ty (/api/Settings/company).
class SettingsService {
  final ApiClient _api;

  SettingsService(this._api);

  Future<CompanySettings> getCompany() async =>
      CompanySettings.fromJson(await _api.get('/api/Settings/company') as Map<String, dynamic>);

  Future<void> saveCompany(CompanySettings settings) => _api.put('/api/Settings/company', data: settings.toJson());
}

/// Đơn nghỉ phép (/api/Leaves). Admin: list/approve/reject. Nhân viên: list (chỉ thấy đơn của mình) + create/update/delete.
class LeaveService {
  final ApiClient _api;

  LeaveService(this._api);

  /// [status] = pending | approved | rejected, null = tất cả.
  Future<List<LeaveRequest>> list({String? status, int? userId}) async {
    final data = await _api.get('/api/Leaves', query: {
      'status': ?status,
      'userId': ?userId,
    }) as List;
    return data.map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> approve(int id, {String? note}) => _api.put('/api/Leaves/$id/approve', data: {'adminNote': note});

  Future<void> reject(int id, {String? note}) => _api.put('/api/Leaves/$id/reject', data: {'adminNote': note});

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Nhân viên tạo đơn. Ném ApiException 400 nếu trùng khoảng ngày với đơn khác.
  Future<void> create({required DateTime from, required DateTime to, required String reason}) =>
      _api.post('/api/Leaves', data: {'fromDate': _day(from), 'toDate': _day(to), 'reason': reason});

  /// Chỉ sửa được đơn đang chờ duyệt (409 nếu đã xử lý).
  Future<void> update(int id, {required DateTime from, required DateTime to, required String reason}) =>
      _api.put('/api/Leaves/$id', data: {'fromDate': _day(from), 'toDate': _day(to), 'reason': reason});

  /// Chỉ xóa được đơn đang chờ duyệt (409 nếu đã xử lý).
  Future<void> delete(int id) => _api.delete('/api/Leaves/$id');
}

/// Báo cáo tháng của admin (/api/Reports/monthly...).
class ReportService {
  final ApiClient _api;

  ReportService(this._api);

  static String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  Future<MonthlyReport> monthly(DateTime month) async =>
      MonthlyReport.fromJson(await _api.get('/api/Reports/monthly', query: {'month': monthKey(month)}) as Map<String, dynamic>);

  /// Một nhân viên, kèm chi tiết từng ngày (`days`).
  Future<MonthlySummary> monthlyForUser(int userId, DateTime month) async {
    final data = await _api.get('/api/Reports/monthly/$userId', query: {'month': monthKey(month)}) as Map<String, dynamic>;
    return MonthlySummary.fromJson((data['rows'] as List).first as Map<String, dynamic>);
  }
}

/// Admin xem / xử lý chấm công (/api/Attendances...).
class AdminAttendanceService {
  final ApiClient _api;

  AdminAttendanceService(this._api);

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Attendance>> list({int? userId, DateTime? from, DateTime? to, String? status}) async {
    final data = await _api.get('/api/Attendances', query: {
      'userId': ?userId,
      'from': ?(from == null ? null : _day(from)),
      'to': ?(to == null ? null : _day(to)),
      'status': ?status,
    }) as List;
    return data.map((e) => Attendance.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Gỡ cờ nghi ngờ (409 nếu bản ghi không bị nghi ngờ).
  Future<void> review(int id, {String? note}) => _api.put('/api/Attendances/$id/review', data: {'note': note});

  /// Đóng bản ghi quên check-out, [checkOutTime] dạng "HH:mm" (giờ địa phương công ty, trong ngày làm việc).
  Future<void> close(int id, {required String checkOutTime, String? note}) =>
      _api.put('/api/Attendances/$id/close', data: {'checkOutTime': checkOutTime, 'note': note});
}
