import 'package:buidoananhviet/core/format.dart';
import 'package:buidoananhviet/screens/auth/login_screen.dart';
import 'package:buidoananhviet/screens/employee/change_password_screen.dart';
import 'package:buidoananhviet/screens/employee/leave_form_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fake_employee_backend.dart';
import 'helpers.dart';

Finder field(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText));

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await settle(tester);
}

Future<FakeEmployeeBackend> openEmployee(WidgetTester tester, {FakeEmployeeBackend? backend}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final fake = backend ?? FakeEmployeeBackend();
  final storage = FakeTokenStorage(token: makeJwt(), fullName: 'Nguyễn Văn An');
  final t = buildTestApp(storage, fake.adapter);
  await t.auth.init();
  await tester.pumpWidget(t.app);
  await settle(tester);
  return fake;
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('Tab Hôm nay', () {
    testWidgets('4 tab, lời chào, ngày, ca chưa chấm và ca đã chấm xong', (tester) async {
      final fake = await openEmployee(tester);
      for (final label in ['Hôm nay', 'Lịch sử', 'Nghỉ phép', 'Hồ sơ']) {
        expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
      }
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text(Fmt.weekdayDate(fake.now)), findsOneWidget);
      expect(find.text('Chưa chấm công'), findsNWidgets(2));
      expect(find.byKey(const Key('checkin_button')), findsOneWidget);
    });

    testWidgets('hiện trạng thái, giờ vào/ra, trễ, phạt, lương và cảnh báo khi đã chấm công', (tester) async {
      final fake = FakeEmployeeBackend();
      fake.todayAttendance[1] = record(9, fake.now, status: 'late', late: 20, hours: 3.5, pay: 85000);
      fake.todayAttendance[2] = record(10, fake.now, status: 'suspicious', shift: 'Ca chiều', reason: 'GPS giả (mock location)', open: true);
      await openEmployee(tester, backend: fake);
      expect(find.text('Đi trễ'), findsOneWidget);
      expect(find.text('Nghi ngờ'), findsOneWidget);
      expect(find.textContaining('Đi trễ 20 phút · phạt'), findsOneWidget);
      expect(find.textContaining('Lương ca:'), findsOneWidget);
      expect(find.textContaining('chưa check-out'), findsOneWidget);
      expect(find.text('Cảnh báo: GPS giả (mock location)'), findsOneWidget);
    });

    testWidgets('nút Chấm công mở luồng chấm công (chi tiết ở check_flow_test)', (tester) async {
      await openEmployee(tester);
      await tester.tap(find.byKey(const Key('checkin_button')));
      await settle(tester);
      expect(find.text('Chọn ca cần chấm công'), findsOneWidget);
    });

    testWidgets('có đơn nghỉ phép đã duyệt hôm nay -> banner', (tester) async {
      await openEmployee(tester, backend: FakeEmployeeBackend()..onLeave = true);
      expect(find.textContaining('đơn nghỉ phép đã được duyệt'), findsOneWidget);
    });

    testWidgets('không có ca -> trạng thái rỗng; lỗi server -> Thử lại', (tester) async {
      final empty = FakeEmployeeBackend()..todayShifts = [];
      await openEmployee(tester, backend: empty);
      expect(find.text('Hôm nay chưa có ca làm việc'), findsOneWidget);
    });

    testWidgets('lỗi server -> màn lỗi, bấm Thử lại thì tải được', (tester) async {
      final fake = FakeEmployeeBackend()..failToday = true;
      await openEmployee(tester, backend: fake);
      expect(find.text('Internal server error'), findsOneWidget);
      fake.failToday = false;
      await tester.tap(find.text('Thử lại'));
      await settle(tester);
      expect(find.text('Ca sáng'), findsOneWidget);
    });
  });

  group('Tab Lịch sử', () {
    testWidgets('thống kê tháng + danh sách có màu/nhãn trạng thái, giờ làm, phạt, lương', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Lịch sử');
      expect(find.text('Tháng ${fake.thisMonth.month}/${fake.thisMonth.year}'), findsOneWidget);
      expect(find.textContaining('230.000'), findsOneWidget); // lương tạm tính
      expect(find.text('Đi trễ'), findsWidgets);
      expect(find.text('Nghi ngờ'), findsWidgets);
      expect(find.textContaining('Trễ 20 phút · phạt'), findsOneWidget);
      expect(find.textContaining('Cảnh báo: GPS giả'), findsOneWidget);
      expect(find.textContaining('lần chấm công bị đánh dấu nghi ngờ'), findsOneWidget);
      expect(find.textContaining('chưa check-out nên chưa được tính lương'), findsOneWidget);
    });

    testWidgets('biểu đồ giờ làm theo ngày trong tháng đang xem', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Lịch sử');
      List<double> values() => tester
          .widget<BarChart>(find.descendant(of: find.byKey(const Key('history_hours_chart')), matching: find.byType(BarChart)))
          .data
          .barGroups
          .map((g) => g.barRods.first.toY)
          .toList();
      final lastDay = DateTime(fake.thisMonth.year, fake.thisMonth.month + 1, 0).day;
      expect(find.text('Giờ làm theo ngày'), findsOneWidget);
      expect(values().length, lastDay);
      expect(values().sublist(0, 3), [3.5, 4, 0]);

      // tháng trước không có dữ liệu ngày -> thông báo thay vì biểu đồ trống
      await tester.tap(find.byKey(const Key('month_prev')));
      await settle(tester);
      expect(find.text('Chưa có dữ liệu để vẽ biểu đồ'), findsOneWidget);
    });

    testWidgets('mũi tên tháng trước/sau; không đi quá tháng hiện tại', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Lịch sử');
      expect(tester.widget<IconButton>(find.byKey(const Key('month_next'))).onPressed, isNull);

      await tester.tap(find.byKey(const Key('month_prev')));
      await settle(tester);
      expect(find.text('Tháng ${fake.prevMonth.month}/${fake.prevMonth.year}'), findsOneWidget);
      expect(find.textContaining('100.000'), findsWidgets);
      expect(fake.adapter.requests.any((r) => r.path == '/api/Reports/my-monthly' && r.queryParameters['month'] == monthKey(fake.prevMonth)), true);
      expect(tester.widget<IconButton>(find.byKey(const Key('month_next'))).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('month_next')));
      await settle(tester);
      expect(find.text('Tháng ${fake.thisMonth.month}/${fake.thisMonth.year}'), findsOneWidget);
      expect(find.textContaining('230.000'), findsOneWidget);
    });

    testWidgets('tháng không có dữ liệu -> trạng thái rỗng', (tester) async {
      await openEmployee(tester);
      await openTab(tester, 'Lịch sử');
      await tester.tap(find.byKey(const Key('month_prev')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('month_prev')));
      await settle(tester);
      expect(find.textContaining('Chưa có chấm công trong tháng'), findsOneWidget);
    });
  });

  group('Tab Nghỉ phép', () {
    testWidgets('đơn chờ duyệt có Sửa/Xóa, đơn đã duyệt thì ẩn và hiện phản hồi của admin', (tester) async {
      await openEmployee(tester);
      await openTab(tester, 'Nghỉ phép');
      expect(find.text('10/11/2026 - 12/11/2026'), findsOneWidget);
      expect(find.byKey(const Key('leave_edit_1')), findsOneWidget);
      expect(find.byKey(const Key('leave_delete_1')), findsOneWidget);
      expect(find.byKey(const Key('leave_edit_2')), findsNothing);
      expect(find.byKey(const Key('leave_delete_2')), findsNothing);
      expect(find.text('Phản hồi: Duyệt rồi nhé'), findsOneWidget);
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.text('Đã duyệt'), findsOneWidget);
    });

    testWidgets('tạo đơn: validate, chọn ngày bằng lịch, gửi lên server, đơn mới hiện ra', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Nghỉ phép');
      await tester.tap(find.byKey(const Key('leave_add')));
      await settle(tester);
      expect(find.byType(LeaveFormScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('lf_submit')));
      await tester.pump();
      expect(find.text('Vui lòng chọn ngày nghỉ'), findsOneWidget);
      expect(find.text('Lý do không được để trống'), findsOneWidget);

      // chọn 1 ngày trong lịch (hôm nay, bấm 2 lần = khoảng 1 ngày) rồi xác nhận
      await tester.tap(find.byKey(const Key('lf_range')));
      await settle(tester);
      final day = find.text('${fake.now.day}').first;
      await tester.tap(day);
      await tester.pump();
      await tester.tap(day);
      await tester.pump();
      await tester.tap(find.text('Chọn'));
      await settle(tester);
      expect(find.textContaining('(1 ngày)'), findsOneWidget);

      await tester.enterText(field('lf_reason'), 'Đi khám răng');
      await tester.tap(find.byKey(const Key('lf_submit')));
      await settle(tester);
      expect(find.byType(LeaveFormScreen), findsNothing);
      expect(find.text('Đi khám răng'), findsOneWidget);
      final post = fake.adapter.requests.firstWhere((r) => r.method == 'POST' && r.path == '/api/Leaves').data as Map;
      expect(post['fromDate'], isoDay(fake.now));
      expect(post['toDate'], isoDay(fake.now));
      expect(post['reason'], 'Đi khám răng');
    });

    testWidgets('sửa đơn chờ duyệt: form điền sẵn, lưu gửi PUT', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Nghỉ phép');
      await tester.tap(find.byKey(const Key('leave_edit_1')));
      await settle(tester);
      expect(tester.widget<EditableText>(field('lf_reason')).controller.text, 'Việc gia đình');
      expect(find.text('10/11/2026 - 12/11/2026  (3 ngày)'), findsOneWidget);
      await tester.enterText(field('lf_reason'), 'Việc gia đình (cập nhật)');
      await tester.tap(find.byKey(const Key('lf_submit')));
      await settle(tester);
      final put = fake.adapter.requests.firstWhere((r) => r.method == 'PUT' && r.path == '/api/Leaves/1').data as Map;
      expect(put['fromDate'], '2026-11-10');
      expect(put['toDate'], '2026-11-12');
      expect(find.text('Việc gia đình (cập nhật)'), findsOneWidget);
    });

    testWidgets('xóa đơn chờ duyệt (có xác nhận)', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Nghỉ phép');
      await tester.tap(find.byKey(const Key('leave_delete_1')));
      await settle(tester);
      expect(find.text('Xóa đơn nghỉ phép?'), findsOneWidget);
      await tester.tap(find.text('Xóa').last);
      await settle(tester);
      expect(fake.leaves.any((l) => l['id'] == 1), false);
      expect(find.text('Việc gia đình'), findsNothing);
    });

    testWidgets('đơn bị admin xử lý trong lúc đang xem: sửa -> 409 hiện lỗi, ở lại form', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Nghỉ phép');
      fake.leaves.firstWhere((l) => l['id'] == 1)['status'] = 'approved'; // admin vừa duyệt
      await tester.tap(find.byKey(const Key('leave_edit_1')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('lf_submit')));
      await settle(tester);
      expect(find.text('Chỉ sửa được đơn đang chờ duyệt'), findsOneWidget);
      expect(find.byType(LeaveFormScreen), findsOneWidget);
    });

    testWidgets('chưa có đơn nào -> trạng thái rỗng', (tester) async {
      final fake = FakeEmployeeBackend()..leaves.clear();
      await openEmployee(tester, backend: fake);
      await openTab(tester, 'Nghỉ phép');
      expect(find.text('Bạn chưa có đơn nghỉ phép'), findsOneWidget);
    });
  });

  group('Tab Hồ sơ', () {
    testWidgets('hiện thông tin cá nhân và lương tạm tính tháng này', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Hồ sơ');
      expect(find.byKey(const Key('profile_fullname')), findsOneWidget);
      expect(find.text('an.nguyen@timeguard.local'), findsOneWidget);
      expect(find.text('Lương tạm tính tháng ${fake.thisMonth.month}/${fake.thisMonth.year}'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('profile_net_pay'))).data, contains('230.000'));
      expect(find.textContaining('30.000'), findsWidgets); // lương theo giờ
      expect(fake.adapter.requests.any((r) => r.path == '/api/Reports/my-monthly' && r.queryParameters['month'] == monthKey(fake.thisMonth)), true);
    });

    testWidgets('sửa họ tên: gửi PUT, hồ sơ và lời chào ở tab Hôm nay cập nhật', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Hồ sơ');
      await tester.tap(find.byKey(const Key('profile_edit_name')));
      await settle(tester);
      await tester.enterText(field('profile_name_field'), '');
      await tester.tap(find.byKey(const Key('profile_name_save')));
      await tester.pump();
      expect(find.text('Họ và tên không được để trống'), findsOneWidget);
      await tester.enterText(field('profile_name_field'), 'Nguyễn An Khang');
      await tester.tap(find.byKey(const Key('profile_name_save')));
      await settle(tester);
      expect((fake.adapter.requests.firstWhere((r) => r.method == 'PUT' && r.path == '/api/Users/me').data as Map)['fullName'], 'Nguyễn An Khang');
      expect(tester.widget<Text>(find.byKey(const Key('profile_fullname'))).data, 'Nguyễn An Khang');
      await openTab(tester, 'Hôm nay');
      expect(find.text('Nguyễn An Khang'), findsOneWidget);
    });

    testWidgets('đổi mật khẩu: validate, sai mật khẩu hiện tại, thành công', (tester) async {
      final fake = await openEmployee(tester);
      await openTab(tester, 'Hồ sơ');
      await tester.ensureVisible(find.byKey(const Key('profile_change_password')));
      await tester.tap(find.byKey(const Key('profile_change_password')));
      await settle(tester);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);

      await tester.enterText(field('cp_current'), 'matkhau1');
      await tester.enterText(field('cp_new'), 'abc');
      await tester.enterText(field('cp_confirm'), 'xyz');
      await tester.tap(find.byKey(const Key('cp_submit')));
      await tester.pump();
      expect(find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);
      expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);

      await tester.enterText(field('cp_current'), 'saimk');
      await tester.enterText(field('cp_new'), 'matkhaumoi');
      await tester.enterText(field('cp_confirm'), 'matkhaumoi');
      await tester.tap(find.byKey(const Key('cp_submit')));
      await settle(tester);
      expect(find.text('Mật khẩu hiện tại không đúng'), findsOneWidget);
      expect(find.byType(ChangePasswordScreen), findsOneWidget);

      await tester.enterText(field('cp_current'), 'matkhau1');
      await tester.tap(find.byKey(const Key('cp_submit')));
      await settle(tester);
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(fake.password, 'matkhaumoi');
    });

    testWidgets('đăng xuất từ Hồ sơ có xác nhận -> về màn đăng nhập', (tester) async {
      await openEmployee(tester);
      await openTab(tester, 'Hồ sơ');
      await tester.ensureVisible(find.byKey(const Key('profile_logout')));
      await tester.tap(find.byKey(const Key('profile_logout')));
      await settle(tester);
      expect(find.text('Đăng xuất?'), findsOneWidget);
      await tester.tap(find.text('Đăng xuất').last);
      await settle(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
