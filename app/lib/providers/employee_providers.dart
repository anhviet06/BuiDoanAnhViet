import '../models/app_user.dart';
import '../models/attendance.dart';
import '../models/leave_request.dart';
import '../models/monthly_report.dart';
import '../services/admin_services.dart';
import '../services/employee_services.dart';
import 'admin_providers.dart';

/// Dashboard "Hôm nay": các ca đang hoạt động + bản ghi chấm công của mình.
class TodayProvider extends LoadableNotifier {
  final AttendanceService _service;
  TodayInfo? info;

  TodayProvider(this._service);

  @override
  Future<void> load() => runLoad(() async => info = await _service.today());
}

/// Lịch sử chấm công theo tháng + thống kê tháng đó.
class HistoryProvider extends LoadableNotifier {
  final AttendanceService _service;
  final DateTime Function() _now;
  late DateTime month;
  List<Attendance> records = [];
  MonthlySummary summary = const MonthlySummary();

  HistoryProvider(this._service, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    final n = _now();
    month = DateTime(n.year, n.month);
  }

  bool get canGoNext {
    final n = _now();
    return month.isBefore(DateTime(n.year, n.month));
  }

  @override
  Future<void> load() => runLoad(() async {
        final from = DateTime(month.year, month.month, 1);
        final to = DateTime(month.year, month.month + 1, 0);
        final results = await Future.wait([_service.history(from: from, to: to), _service.myMonthly(month)]);
        records = results[0] as List<Attendance>;
        summary = results[1] as MonthlySummary;
      });

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

/// Đơn nghỉ phép của chính mình.
class MyLeavesProvider extends LoadableNotifier {
  final LeaveService _service;
  List<LeaveRequest> leaves = [];

  MyLeavesProvider(this._service);

  @override
  Future<void> load() => runLoad(() async => leaves = await _service.list());

  Future<void> _reload() async => leaves = await _service.list();

  Future<void> create({required DateTime from, required DateTime to, required String reason}) async {
    await _service.create(from: from, to: to, reason: reason);
    await _reload();
    notifyListeners();
  }

  Future<void> update(int id, {required DateTime from, required DateTime to, required String reason}) async {
    await _service.update(id, from: from, to: to, reason: reason);
    await _reload();
    notifyListeners();
  }

  Future<void> delete(int id) async {
    await _service.delete(id);
    await _reload();
    notifyListeners();
  }
}

/// Hồ sơ + lương tạm tính tháng hiện tại.
class ProfileProvider extends LoadableNotifier {
  final ProfileService _profile;
  final AttendanceService _attendance;
  final DateTime Function() _now;
  AppUser? user;
  MonthlySummary summary = const MonthlySummary();

  ProfileProvider(this._profile, this._attendance, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  DateTime get month {
    final n = _now();
    return DateTime(n.year, n.month);
  }

  @override
  Future<void> load() => runLoad(() async {
        final results = await Future.wait([_profile.me(), _attendance.myMonthly(month)]);
        user = results[0] as AppUser;
        summary = results[1] as MonthlySummary;
      });

  Future<void> updateName(String fullName) async {
    await _profile.updateName(fullName);
    user = await _profile.me();
    notifyListeners();
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      _profile.changePassword(currentPassword: currentPassword, newPassword: newPassword);
}
