// Test tích hợp với backend THẬT đang chạy. Tự bỏ qua nếu thiếu biến môi trường.
// Test tự tạo user/ca riêng (tên có dấu thời gian), không dùng user/ca seed, và ca được dựng quanh GIỜ HIỆN TẠI
// (qua nửa đêm thì dùng "24:00") nên chạy lúc nào cũng được. Cần backend bật Otp:DevMode (đăng nhập lấy devOtp) và tài khoản "admin".
// LƯU Ý: test 'nhân viên thật' tạo bản ghi chấm công nên user/ca test KHÔNG xóa được qua API (409).
// ĐỪNG chạy trên DB đang dùng: hãy chạy trên DB tạm (ConnectionStrings__DefaultConnection=...Database=Buidoananhviet_it), xem README.
// Nếu lỡ chạy trên DB thật, dọn bằng SQL: delete Attendances where UserId in (select Id from Users where Username like 'emp%' or Username like 'rp%');
// delete Users where Username like 'emp%' or Username like 'rp%' or Username like 'adm%' or Username like 'it%'; delete Shifts where Name like 'Ca ET%' or Name like 'Ca RP%' or Name like 'Ca IT%'.
//   $env:TG_BASE_URL="http://localhost:5000"; $env:TG_ADMIN_PW="..."; flutter test test/backend_integration_test.dart
import 'dart:io';

import 'package:buidoananhviet/models/auth_session.dart';
import 'package:buidoananhviet/models/check_request.dart';
import 'package:buidoananhviet/models/company_settings.dart';
import 'package:buidoananhviet/providers/auth_provider.dart';
import 'package:buidoananhviet/services/api_client.dart';
import 'package:buidoananhviet/services/admin_services.dart';
import 'package:buidoananhviet/services/auth_service.dart';
import 'package:buidoananhviet/services/employee_services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final baseUrl = Platform.environment['TG_BASE_URL'];
  final adminPw = Platform.environment['TG_ADMIN_PW'];
  final skip = (baseUrl == null || adminPw == null) ? 'đặt TG_BASE_URL và TG_ADMIN_PW để chạy' : null;

  test('đăng nhập 2 bước thật, gắn JWT, 401 khi token sai', () async {
    final storage = FakeTokenStorage();
    final api = ApiClient(storage: storage, dio: Dio(BaseOptions(baseUrl: baseUrl!, contentType: Headers.jsonContentType)));
    final auth = AuthProvider(storage, AuthService(api));
    api.onUnauthorized = auth.handleUnauthorized;
    await auth.init();
    expect(auth.status, AuthStatus.unauthenticated);

    // sai mật khẩu -> ApiException có message của server, không đăng xuất
    await expectLater(auth.login('admin', 'sai-mat-khau'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));

    // bước 1 + bước 2 (DevMode trả devOtp)
    final challenge = await auth.login('admin', adminPw!);
    expect(challenge.devOtp, isNotNull, reason: 'cần bật Otp:DevMode');
    await auth.verifyOtp('admin', challenge.devOtp!);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.session!.isAdmin, true);
    expect(storage.token, isNotNull);

    // gọi API cần JWT
    final me = await api.get('/api/Users/me') as Map;
    expect(me['email'], 'admin@timeguard.local');
    final shifts = await api.get('/api/Shifts') as List;
    expect(shifts, isNotEmpty);

    // khởi động lại app: khôi phục phiên từ token đã lưu
    final auth2 = AuthProvider(storage, AuthService(api));
    await auth2.init();
    expect(auth2.session?.role, 'admin');

    // token bị hỏng phía server -> 401 -> tự đăng xuất
    storage.token = '${storage.token}x';
    await expectLater(api.get('/api/Users/me'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    expect(auth.status, AuthStatus.unauthenticated);
    expect(storage.token, isNull);
    expect(AuthSession.fromToken('x'), isNull);
  }, skip: skip);

  test('đăng ký thật -> đăng nhập bằng email VÀ username -> trùng email bị từ chối -> dọn dữ liệu', () async {
    final storage = FakeTokenStorage();
    final api = ApiClient(storage: storage, dio: Dio(BaseOptions(baseUrl: baseUrl!, contentType: Headers.jsonContentType)));
    final service = AuthService(api);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'it$stamp@test.local';
    final username = 'it$stamp';

    await service.register(email: email, password: 'abc123', fullName: 'Test Tich Hop', username: username);
    await expectLater(service.register(email: email, password: 'abc123', fullName: 'Trung'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));

    for (final id in [email, username]) {
      final challenge = await service.login(id, 'abc123');
      final result = await service.verifyOtp(id, challenge.devOtp!);
      final session = AuthSession.fromToken(result.token, fullName: result.fullName)!;
      expect(session.role, 'employee');
      expect(session.fullName, 'Test Tich Hop');
    }

    // dọn: admin xóa user vừa tạo (chưa có chấm công nên xóa cứng được)
    final adminChallenge = await service.login('admin', adminPw!);
    final admin = await service.verifyOtp('admin', adminChallenge.devOtp!);
    storage.token = admin.token;
    final users = await api.get('/api/Users') as List;
    final id = users.firstWhere((u) => u['email'] == email)['id'];
    await api.delete('/api/Users/$id');
  }, skip: skip);

  test('dịch vụ admin thật: nhân viên, ca + QR, cấu hình, nghỉ phép; xong dọn dữ liệu', () async {
    ApiClient clientFor(FakeTokenStorage s) =>
        ApiClient(storage: s, dio: Dio(BaseOptions(baseUrl: baseUrl!, contentType: Headers.jsonContentType)));

    // đăng nhập admin
    final adminStorage = FakeTokenStorage();
    final adminApi = clientFor(adminStorage);
    final auth = AuthService(adminApi);
    final ch = await auth.login('admin', adminPw!);
    adminStorage.token = (await auth.verifyOtp('admin', ch.devOtp!)).token;

    final users = UserService(adminApi);
    final shifts = ShiftService(adminApi);
    final settings = SettingsService(adminApi);
    final leaves = LeaveService(adminApi);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'adm$stamp@test.local';
    int? userId;
    int? shiftId;
    final originalCompany = await settings.getCompany();

    try {
      // --- nhân viên
      await users.create(email: email, username: 'adm$stamp', password: 'abc123', fullName: 'Nhan Vien Test', hourlyRate: 40000, role: 'employee');
      userId = (await users.list()).firstWhere((u) => u.email == email).id;
      await users.update(userId, email: email, username: 'adm$stamp', fullName: 'Nhan Vien Sua', hourlyRate: 50000, role: 'employee');
      var me = (await users.list()).firstWhere((u) => u.id == userId);
      expect(me.fullName, 'Nhan Vien Sua');
      expect(me.hourlyRate, 50000);
      await users.setLocked(userId, true);
      expect((await users.list()).firstWhere((u) => u.id == userId).isLocked, true);
      await expectLater(auth.login(email, 'abc123'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
      await users.setLocked(userId, false);
      await users.resetPassword(userId, 'moi12345');
      await auth.login(email, 'moi12345'); // đăng nhập được bằng mật khẩu mới

      // --- ca + QR
      await shifts.create(name: 'Ca IT $stamp', startTime: '06:00', endTime: '07:00', lateGraceMinutes: 3, isActive: true);
      var shift = (await shifts.list()).firstWhere((s) => s.name == 'Ca IT $stamp');
      shiftId = shift.id;
      expect(shift.startLabel, '06:00');
      expect(shift.qrToken, isNotEmpty);
      final oldToken = shift.qrToken;
      final renewed = await shifts.regenerateQr(shift.id);
      expect(renewed.qrToken, isNot(oldToken));
      await shifts.update(shift.id, name: 'Ca IT $stamp', startTime: '06:30', endTime: '07:30', lateGraceMinutes: 3, isActive: false);
      shift = (await shifts.list()).firstWhere((s) => s.id == shiftId);
      expect(shift.rangeLabel, '06:30 - 07:30');
      expect(shift.isActive, false);
      expect(shift.qrToken, renewed.qrToken, reason: 'sửa ca không đổi QR');

      // --- cấu hình công ty
      await settings.saveCompany(CompanySettings(latitude: 21.0285, longitude: 105.8542, radiusMeters: 123, latePenaltyPerMinute: 2500));
      final c = await settings.getCompany();
      expect([c.latitude, c.longitude, c.radiusMeters, c.latePenaltyPerMinute], [21.0285, 105.8542, 123, 2500]);
      await expectLater(settings.saveCompany(CompanySettings(latitude: 200, longitude: 0, radiusMeters: 10, latePenaltyPerMinute: 0)),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));

      // --- nghỉ phép: nhân viên tạo đơn, admin duyệt / từ chối
      final empStorage = FakeTokenStorage();
      final empApi = clientFor(empStorage);
      final empAuth = AuthService(empApi);
      final ec = await empAuth.login(email, 'moi12345');
      empStorage.token = (await empAuth.verifyOtp(email, ec.devOtp!)).token;
      await empApi.post('/api/Leaves', data: {'fromDate': '2031-01-10', 'toDate': '2031-01-12', 'reason': 'Test A'});
      await empApi.post('/api/Leaves', data: {'fromDate': '2031-02-10', 'toDate': '2031-02-10', 'reason': 'Test B'});
      final pending = (await leaves.list(status: 'pending', userId: userId));
      expect(pending.length, 2);
      expect(pending.first.user?.fullName, 'Nhan Vien Sua');
      final a = pending.firstWhere((l) => l.reason == 'Test A');
      final b = pending.firstWhere((l) => l.reason == 'Test B');
      expect(a.days, 3);
      await leaves.approve(a.id, note: 'OK nhé');
      await leaves.reject(b.id, note: 'Bận');
      expect((await leaves.list(status: 'approved', userId: userId)).single.adminNote, 'OK nhé');
      expect((await leaves.list(status: 'rejected', userId: userId)).single.reason, 'Test B');
      await expectLater(leaves.approve(a.id), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    } finally {
      // dọn dữ liệu test
      await settings.saveCompany(originalCompany);
      if (shiftId != null) await shifts.delete(shiftId);
      if (userId != null) await users.delete(userId);
    }
  }, skip: skip);

  test('nhân viên thật: hồ sơ, đổi mật khẩu, nghỉ phép, chấm công thật -> hôm nay / lịch sử / lương parse đúng', () async {
    ApiClient clientFor(FakeTokenStorage s) =>
        ApiClient(storage: s, dio: Dio(BaseOptions(baseUrl: baseUrl!, contentType: Headers.jsonContentType)));

    final adminStorage = FakeTokenStorage();
    final adminApi = clientFor(adminStorage);
    final adminAuth = AuthService(adminApi);
    final ch = await adminAuth.login('admin', adminPw!);
    adminStorage.token = (await adminAuth.verifyOtp('admin', ch.devOtp!)).token;
    final users = UserService(adminApi);
    final shifts = ShiftService(adminApi);
    final adminLeaves = LeaveService(adminApi);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'emp$stamp@test.local';
    await users.create(email: email, username: 'emp$stamp', password: 'abc123', fullName: 'Nhan Vien ET', hourlyRate: 60000, role: 'employee');

    // ca bao phủ thời điểm hiện tại (giờ ca là UTC+7)
    final local = DateTime.now().toUtc().add(const Duration(hours: 7));
    String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    // Cửa sổ ca an toàn quanh nửa đêm: bắt đầu >= 00:00, kết thúc qua nửa đêm thì dùng "24:00" (server hỗ trợ)
    final start = (local.hour == 0 && local.minute == 0) ? local : local.subtract(const Duration(minutes: 1));
    final endAt = local.add(const Duration(minutes: 90));
    final endText = endAt.day != local.day ? '24:00' : hm(endAt);
    await shifts.create(name: 'Ca ET $stamp', startTime: hm(start), endTime: endText, lateGraceMinutes: 5, isActive: true);
    final shift = (await shifts.list()).firstWhere((s) => s.name == 'Ca ET $stamp');

    final empStorage = FakeTokenStorage();
    final empApi = clientFor(empStorage);
    final empAuth = AuthService(empApi);
    final ec = await empAuth.login(email, 'abc123');
    empStorage.token = (await empAuth.verifyOtp(email, ec.devOtp!)).token;
    final profile = ProfileService(empApi);
    final attendance = AttendanceService(empApi);
    final empLeaves = LeaveService(empApi);

    // --- hồ sơ
    expect((await profile.me()).hourlyRate, 60000);
    await profile.updateName('Nhan Vien ET Moi');
    expect((await profile.me()).fullName, 'Nhan Vien ET Moi');
    await expectLater(profile.changePassword(currentPassword: 'sai', newPassword: 'abc12345'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
    await profile.changePassword(currentPassword: 'abc123', newPassword: 'abc12345');
    await empAuth.login(email, 'abc12345');

    // --- hôm nay (chưa chấm): ca của mình có trong danh sách, chưa có attendance, nhân viên không thấy qrToken
    var today = await attendance.today();
    expect(today.onLeave, false);
    final item = today.items.firstWhere((i) => i.shift.id == shift.id);
    expect(item.attendance, isNull);
    expect(item.shift.qrToken, isNull);

    // --- chấm công thật (luồng đầy đủ làm ở T8, ở đây gọi API trực tiếp)
    final request = CheckRequest(qrToken: shift.qrToken!, latitude: 10.7769, longitude: 106.7009, isMocked: false, deviceId: 'ET-$stamp');
    // các lỗi thật từ server (đều ném ApiException với message tiếng Việt của backend)
    await expectLater(
        attendance.checkIn(CheckRequest(qrToken: 'ma-sai', latitude: 10.7769, longitude: 106.7009, isMocked: false, deviceId: 'ET-$stamp')),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
    await expectLater(
        attendance.checkIn(CheckRequest(qrToken: shift.qrToken!, latitude: 10.80, longitude: 106.7009, isMocked: false, deviceId: 'ET-$stamp')),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('vượt bán kính'))));
    await expectLater(attendance.checkOut(request), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('chưa check-in'))));
    final inRes = await attendance.checkIn(request);
    expect(inRes.attendance.status, 'on-time');
    expect(inRes.attendance.isOpen, true);
    await expectLater(attendance.checkIn(request), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    final outRes = await attendance.checkOut(request);
    expect(outRes.attendance.isOpen, false);

    today = await attendance.today();
    final done = today.items.firstWhere((i) => i.shift.id == shift.id).attendance!;
    expect(done.isOpen, false);
    expect(done.status, 'on-time');
    expect(done.shiftName, 'Ca ET $stamp');
    expect(done.checkInAt.isUtc, true);

    final day = DateTime(today.date.year, today.date.month, today.date.day);
    final history = await attendance.history(from: day, to: day);
    expect(history.length, 1);
    expect(history.single.id, done.id);
    final month = await attendance.myMonthly(day);
    expect(month.daysWorked, 1);
    expect(month.days.length, 1);
    expect(month.hourlyRate, 60000);
    final lastMonth = await attendance.myMonthly(DateTime(day.year, day.month - 1));
    expect(lastMonth.daysWorked, 0);

    // --- nghỉ phép: tạo, sửa, trùng, xóa; đơn đã duyệt thì 409
    await empLeaves.create(from: DateTime(2032, 3, 10), to: DateTime(2032, 3, 12), reason: 'Tao don');
    var mine = await empLeaves.list();
    expect(mine.length, 1);
    await empLeaves.update(mine.single.id, from: DateTime(2032, 3, 10), to: DateTime(2032, 3, 11), reason: 'Sua don');
    mine = await empLeaves.list();
    expect(mine.single.days, 2);
    await expectLater(empLeaves.create(from: DateTime(2032, 3, 11), to: DateTime(2032, 3, 15), reason: 'Trung'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
    await adminLeaves.approve(mine.single.id, note: 'OK');
    await expectLater(empLeaves.update(mine.single.id, from: DateTime(2032, 3, 10), to: DateTime(2032, 3, 11), reason: 'x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    await expectLater(empLeaves.delete(mine.single.id), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    await empLeaves.create(from: DateTime(2032, 4, 1), to: DateTime(2032, 4, 1), reason: 'Se xoa');
    final toDelete = (await empLeaves.list()).firstWhere((l) => l.reason == 'Se xoa');
    await empLeaves.delete(toDelete.id);
    expect((await empLeaves.list()).length, 1);
  }, skip: skip);

  test('báo cáo + xử lý chấm công admin thật: nghi ngờ -> gỡ cờ, quên check-out -> đóng ca; báo cáo tách tiền nghi ngờ', () async {
    ApiClient clientFor(FakeTokenStorage s) =>
        ApiClient(storage: s, dio: Dio(BaseOptions(baseUrl: baseUrl!, contentType: Headers.jsonContentType)));

    final adminStorage = FakeTokenStorage();
    final adminApi = clientFor(adminStorage);
    final adminAuth = AuthService(adminApi);
    final ch = await adminAuth.login('admin', adminPw!);
    adminStorage.token = (await adminAuth.verifyOtp('admin', ch.devOtp!)).token;
    final users = UserService(adminApi);
    final shifts = ShiftService(adminApi);
    final reports = ReportService(adminApi);
    final admin = AdminAttendanceService(adminApi);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    Future<(AttendanceService, int)> makeEmployee(String tag) async {
      final email = '$tag$stamp@test.local';
      await users.create(email: email, username: '$tag$stamp', password: 'abc123', fullName: 'NV $tag', hourlyRate: 60000, role: 'employee');
      final id = (await users.list()).firstWhere((u) => u.email == email).id;
      final storage = FakeTokenStorage();
      final api = clientFor(storage);
      final auth = AuthService(api);
      final c = await auth.login(email, 'abc123');
      storage.token = (await auth.verifyOtp(email, c.devOtp!)).token;
      return (AttendanceService(api), id);
    }

    final local = DateTime.now().toUtc().add(const Duration(hours: 7));
    String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final endAt = local.add(const Duration(minutes: 90));
    final endText = endAt.day != local.day ? '24:00' : hm(endAt);
    final startAt = (local.hour == 0 && local.minute == 0) ? local : local.subtract(const Duration(minutes: 1));
    await shifts.create(name: 'Ca RP $stamp', startTime: hm(startAt), endTime: endText, lateGraceMinutes: 5, isActive: true);
    final shift = (await shifts.list()).firstWhere((s) => s.name == 'Ca RP $stamp');

    final (empA, idA) = await makeEmployee('rpa');
    final (empB, idB) = await makeEmployee('rpb');
    CheckRequest req(String dev, {bool mocked = false}) =>
        CheckRequest(qrToken: shift.qrToken!, latitude: 10.7769, longitude: 106.7009, isMocked: mocked, deviceId: dev);

    // A: GPS giả -> nghi ngờ. B: check-in rồi "quên" check-out
    final a = await empA.checkIn(req('RP-A-$stamp', mocked: true));
    expect(a.attendance.status, 'suspicious');
    final b = await empB.checkIn(req('RP-B-$stamp'));
    expect(b.attendance.isOpen, true);

    final month = DateTime(local.year, local.month);
    var report = await reports.monthly(month);
    final rowA = report.rows.firstWhere((r) => r.userId == idA);
    expect(rowA.suspiciousCount, 1);
    expect(report.totalSuspicious, greaterThanOrEqualTo(1));
    expect(report.rows.firstWhere((r) => r.userId == idB).openCount, 1);

    // lọc admin
    final today = DateTime(local.year, local.month, local.day);
    final suspicious = await admin.list(status: 'suspicious', from: today, to: today);
    expect(suspicious.any((x) => x.id == a.attendance.id), true);
    final onlyB = await admin.list(userId: idB, from: today, to: today);
    expect(onlyB.single.id, b.attendance.id);

    // gỡ cờ: 200; gỡ lại -> 409; bản ghi B không nghi ngờ -> 409
    await admin.review(a.attendance.id, note: 'Đã kiểm tra');
    await expectLater(admin.review(a.attendance.id), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    await expectLater(admin.review(b.attendance.id), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    final afterReview = (await admin.list(userId: idA, from: today, to: today)).single;
    expect(afterReview.isSuspicious, false);
    expect(afterReview.wasReviewed, true);
    expect(afterReview.adminNote, 'Đã kiểm tra');
    report = await reports.monthly(month);
    expect(report.rows.firstWhere((r) => r.userId == idA).suspiciousCount, 0);

    // đóng ca: giờ ra ở tương lai hoặc trước giờ vào bị từ chối
    await expectLater(admin.close(b.attendance.id, checkOutTime: '00:00'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
    final future = local.add(const Duration(hours: 1));
    if (future.day == local.day) {
      await expectLater(admin.close(b.attendance.id, checkOutTime: hm(future)), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('tương lai'))));
    }
    // đợi sang phút kế tiếp để giờ ra (HH:mm) không nhỏ hơn giờ vào (có giây)
    await Future<void>.delayed(const Duration(seconds: 65));
    final nowLocal = DateTime.now().toUtc().add(const Duration(hours: 7));
    await admin.close(b.attendance.id, checkOutTime: hm(nowLocal), note: 'Quên chấm ra');
    final closed = (await admin.list(userId: idB, from: today, to: today)).single;
    expect(closed.isOpen, false);
    expect(closed.wasClosedByAdmin, true);
    expect(closed.adminNote, 'Quên chấm ra');
    await expectLater(admin.close(b.attendance.id, checkOutTime: hm(nowLocal)), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));

    final detail = await reports.monthlyForUser(idB, month);
    expect(detail.openCount, 0);
    expect(detail.daysWorked, 1);
    expect(detail.days.single.date.day, local.day);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('đăng ký -> OTP xác thực email -> mới vào app (backend thật, DevMode)', () async {
    final storage = FakeTokenStorage();
    final api = ApiClient(storage: storage, dio: Dio(BaseOptions(baseUrl: baseUrl!, contentType: Headers.jsonContentType)));
    final auth = AuthProvider(storage, AuthService(api));
    api.onUnauthorized = auth.handleUnauthorized;
    await auth.init();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'reg$stamp@test.local';

    // đăng ký có nhập tên đăng nhập riêng
    final challenge = await auth.register(email: email, password: 'abc123', fullName: 'Nguoi Dang Ky', username: 'tuchon$stamp');
    expect(challenge.devOtp, isNotNull, reason: 'cần bật Otp:DevMode');
    expect(auth.status, AuthStatus.unauthenticated, reason: 'chưa xác thực email thì chưa vào app');
    expect(storage.token, isNull);

    await expectLater(auth.verifyOtp(email, '000000'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    await auth.verifyOtp(email, challenge.devOtp!);
    expect(auth.status, AuthStatus.authenticated);
    expect(auth.session!.role, 'employee');
    expect(auth.session!.fullName, 'Nguoi Dang Ky');
    expect(auth.session!.username, 'tuchon$stamp');

    // bỏ trống username -> phần trước @
    final c2 = await AuthService(api).register(email: 'reg2$stamp@test.local', password: 'abc123', fullName: 'Hai');
    final r2 = await AuthService(api).verifyOtp('reg2$stamp@test.local', c2.devOtp!);
    expect(AuthSession.fromToken(r2.token)!.username, 'reg2$stamp');

    // dọn: admin xóa 2 tài khoản test
    final adminStorage = FakeTokenStorage();
    final adminApi = ApiClient(storage: adminStorage, dio: Dio(BaseOptions(baseUrl: baseUrl, contentType: Headers.jsonContentType)));
    final adminAuth = AuthService(adminApi);
    final ch = await adminAuth.login('admin', adminPw!);
    adminStorage.token = (await adminAuth.verifyOtp('admin', ch.devOtp!)).token;
    final users = UserService(adminApi);
    for (final u in (await users.list()).where((u) => u.email == email || u.email == 'reg2$stamp@test.local')) {
      await users.delete(u.id);
    }
  }, skip: skip);
}
