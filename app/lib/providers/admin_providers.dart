import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/attendance.dart';
import '../models/company_settings.dart';
import '../models/leave_request.dart';
import '../models/monthly_report.dart';
import '../models/shift.dart';
import '../services/admin_services.dart';
import '../services/api_client.dart';

/// Nền chung cho provider của một danh sách tải từ API: có trạng thái loading/lỗi,
/// và an toàn khi bị dispose giữa lúc đang gọi API (vd đăng xuất).
abstract class LoadableNotifier extends ChangeNotifier {
  bool _loading = true;
  bool _disposed = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  Future<void> load();

  /// Tải có hiện vòng xoay; lỗi được lưu vào [error] thay vì ném ra.
  Future<void> runLoad(Future<void> Function() fetch) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await fetch();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';
    }
    _loading = false;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Danh sách người dùng + thao tác của admin. Các hàm ghi ném ApiException để UI hiện lỗi.
class UsersProvider extends LoadableNotifier {
  final UserService _service;
  List<AppUser> users = [];

  UsersProvider(this._service);

  @override
  Future<void> load() => runLoad(() async => users = await _service.list());

  Future<void> _reload() async => users = await _service.list();

  Future<void> create({
    required String email,
    required String username,
    required String password,
    required String fullName,
    required double hourlyRate,
    required String role,
  }) async {
    await _service.create(
        email: email, username: username, password: password, fullName: fullName, hourlyRate: hourlyRate, role: role);
    await _reload();
    notifyListeners();
  }

  Future<void> update(
    int id, {
    required String email,
    required String username,
    required String fullName,
    required double hourlyRate,
    required String role,
  }) async {
    await _service.update(id,
        email: email, username: username, fullName: fullName, hourlyRate: hourlyRate, role: role);
    await _reload();
    notifyListeners();
  }

  Future<void> setLocked(int id, bool locked) async {
    await _service.setLocked(id, locked);
    await _reload();
    notifyListeners();
  }

  Future<void> resetPassword(int id, String newPassword) => _service.resetPassword(id, newPassword);

  Future<void> delete(int id) async {
    await _service.delete(id);
    await _reload();
    notifyListeners();
  }
}

class ShiftsProvider extends LoadableNotifier {
  final ShiftService _service;
  List<Shift> shifts = [];

  ShiftsProvider(this._service);

  Shift? byId(int id) {
    for (final s in shifts) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<void> load() => runLoad(() async => shifts = await _service.list());

  Future<void> _reload() async => shifts = await _service.list();

  Future<void> create(
      {required String name,
      required String startTime,
      required String endTime,
      required int lateGraceMinutes,
      required bool isActive}) async {
    await _service.create(
        name: name, startTime: startTime, endTime: endTime, lateGraceMinutes: lateGraceMinutes, isActive: isActive);
    await _reload();
    notifyListeners();
  }

  Future<void> update(int id,
      {required String name,
      required String startTime,
      required String endTime,
      required int lateGraceMinutes,
      required bool isActive}) async {
    await _service.update(id,
        name: name, startTime: startTime, endTime: endTime, lateGraceMinutes: lateGraceMinutes, isActive: isActive);
    await _reload();
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await _service.delete(id);
    await _reload();
    notifyListeners();
  }

  Future<void> regenerateQr(int id) async {
    await _service.regenerateQr(id);
    await _reload();
    notifyListeners();
  }
}

/// Đơn nghỉ phép cho admin duyệt. [statusFilter] null = tất cả.
class LeavesProvider extends LoadableNotifier {
  final LeaveService _service;
  List<LeaveRequest> leaves = [];
  String? statusFilter = 'pending';

  LeavesProvider(this._service);

  @override
  Future<void> load() => runLoad(() async => leaves = await _service.list(status: statusFilter));

  Future<void> setFilter(String? status) {
    statusFilter = status;
    return load();
  }

  Future<void> _reload() async => leaves = await _service.list(status: statusFilter);

  Future<void> approve(int id, {String? note}) async {
    await _service.approve(id, note: note);
    await _reload();
    notifyListeners();
  }

  Future<void> reject(int id, {String? note}) async {
    await _service.reject(id, note: note);
    await _reload();
    notifyListeners();
  }
}

class CompanySettingsProvider extends LoadableNotifier {
  final SettingsService _service;
  CompanySettings? settings;

  CompanySettingsProvider(this._service);

  @override
  Future<void> load() => runLoad(() async => settings = await _service.getCompany());

  Future<void> save(CompanySettings value) async {
    await _service.saveCompany(value);
    settings = value;
    notifyListeners();
  }
}

/// Báo cáo tháng của mọi nhân viên, chọn tháng bằng mũi tên.
class ReportsProvider extends LoadableNotifier {
  final ReportService _service;
  final DateTime Function() _now;
  late DateTime month;
  MonthlyReport report = const MonthlyReport();

  ReportsProvider(this._service, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    final n = _now();
    month = DateTime(n.year, n.month);
  }

  bool get canGoNext {
    final n = _now();
    return month.isBefore(DateTime(n.year, n.month));
  }

  @override
  Future<void> load() => runLoad(() async => report = await _service.monthly(month));

  Future<void> previousMonth() {
    month = DateTime(month.year, month.month - 1);
    return load();
  }

  Future<void> nextMonth() {
    if (!canGoNext) return Future.value();
    month = DateTime(month.year, month.month + 1);
    return load();
  }
}

/// Chi tiết báo cáo tháng của một nhân viên (kèm từng ngày).
class UserReportProvider extends LoadableNotifier {
  final ReportService _service;
  final int userId;
  final DateTime month;
  MonthlySummary? summary;

  UserReportProvider(this._service, {required this.userId, required this.month});

  @override
  Future<void> load() => runLoad(() async => summary = await _service.monthlyForUser(userId, month));
}

/// Danh sách chấm công cho admin với bộ lọc (nhân viên, khoảng ngày, trạng thái) + hành động xử lý.
/// [openOnly] = chỉ các bản ghi chưa check-out (lọc phía client vì server không có trạng thái "open").
class AdminAttendancesProvider extends LoadableNotifier {
  final AdminAttendanceService _service;
  int? userId;
  DateTime from;
  DateTime to;
  String? status; // null = tất cả
  bool openOnly = false;
  List<Attendance> records = [];

  AdminAttendancesProvider(this._service, {this.userId, required this.from, required this.to, this.status, this.openOnly = false});

  @override
  Future<void> load() => runLoad(_fetch);

  Future<void> _fetch() async {
    final list = await _service.list(userId: userId, from: from, to: to, status: openOnly ? null : status);
    records = openOnly ? list.where((a) => a.isOpen).toList() : list;
  }

  /// Đổi bộ lọc rồi tải lại. Tham số bỏ trống = giữ nguyên.
  Future<void> setFilters({int? Function()? userId, DateTime? from, DateTime? to, String? Function()? status, bool? openOnly}) {
    if (userId != null) this.userId = userId();
    if (from != null) this.from = from;
    if (to != null) this.to = to;
    if (status != null) this.status = status();
    if (openOnly != null) this.openOnly = openOnly;
    return load();
  }

  Future<void> review(int id, {String? note}) async {
    await _service.review(id, note: note);
    await _fetch();
    notifyListeners();
  }

  Future<void> close(int id, {required String checkOutTime, String? note}) async {
    await _service.close(id, checkOutTime: checkOutTime, note: note);
    await _fetch();
    notifyListeners();
  }
}
