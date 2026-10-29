import 'package:buidoananhviet/core/format.dart';
import 'package:buidoananhviet/models/monthly_report.dart';
import 'package:buidoananhviet/screens/admin/attendances_admin_screen.dart';
import 'package:buidoananhviet/screens/admin/report_detail_screen.dart';
import 'package:buidoananhviet/widgets/charts.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fake_employee_backend.dart';
import 'helpers.dart';

Map<String, dynamic> attendance(int id, int userId, String name, {String status = 'on-time', bool open = false, String? reason, int late = 0, String shift = 'Ca sáng', String? adminAction, String? adminNote, double pay = 120000, required DateTime day}) => {
      'id': id,
      'userId': userId,
      'userName': name,
      'shiftId': 1,
      'shiftName': shift,
      'shiftStartTime': '08:00:00',
      'shiftEndTime': '12:00:00',
      'workDate': '${isoDay(day)}T00:00:00',
      'checkInAt': '${isoDay(day)}T01:00:00Z',
      'checkOutAt': open ? null : '${isoDay(day)}T05:00:00Z',
      'distanceMeters': 10,
      'status': status,
      'suspiciousReason': reason,
      'isMockedLocation': false,
      'lateMinutes': late,
      'workedHours': open ? 0 : 4,
      'latePenalty': late * 1000,
      'grossPay': open ? 0 : 120000,
      'pay': open ? 0 : pay,
      'adminAction': adminAction,
      'adminNote': adminNote,
      'adminActionAt': adminAction == null ? null : '${isoDay(day)}T08:00:00Z',
    };

/// Backend giả cho tab Báo cáo và màn Quản lý chấm công (admin id = 1).
class FakeReportsBackend {
  final DateTime now = DateTime.now();
  late final DateTime thisMonth = DateTime(now.year, now.month);
  late final DateTime prevMonth = DateTime(now.year, now.month - 1);
  String? closeError;
  late final List<Map<String, dynamic>> records;
  late final FakeBackend adapter;

  FakeReportsBackend() {
    final d = DateTime(thisMonth.year, thisMonth.month, 1);
    records = [
      attendance(1, 2, 'Nguyễn Văn An', status: 'suspicious', reason: 'GPS giả (mock location)', late: 20, day: d),
      attendance(2, 3, 'Trần Thị Bình', open: true, day: d),
      attendance(3, 2, 'Nguyễn Văn An', status: 'late', late: 10, shift: 'Ca chiều', day: DateTime(thisMonth.year, thisMonth.month, 2)),
    ];
    adapter = FakeBackend(_handle);
  }

  static Map<String, dynamic> row(int id, String name, {double hours = 0, double net = 0, double penalty = 0, int suspicious = 0, double suspiciousPay = 0, int open = 0, List<Map<String, dynamic>> days = const []}) => {
        'userId': id, 'fullName': name, 'hourlyRate': 30000, 'daysWorked': 2, 'openCount': open, 'totalHours': hours,
        'lateCount': 1, 'totalLateMinutes': 20, 'totalPenalty': penalty, 'grossPay': net + penalty, 'netPay': net,
        'suspiciousCount': suspicious, 'suspiciousPay': suspiciousPay, 'leaveDays': 0, 'days': days,
      };

  Map<String, dynamic> report(String month) {
    if (month == monthKey(thisMonth)) {
      return {
        'month': month,
        'rows': [
          row(2, 'Nguyễn Văn An', hours: 7.5, net: 230000, penalty: 20000, suspicious: 1, suspiciousPay: 120000, open: 1),
          row(3, 'Trần Thị Bình', hours: 4, net: 100000),
        ],
        'totalHours': 11.5, 'totalPenalty': 20000, 'totalNetPay': 330000, 'totalGrossPay': 350000, 'totalSuspicious': 1, 'totalSuspiciousPay': 120000,
      };
    }
    if (month == monthKey(prevMonth)) {
      return {
        'month': month,
        'rows': [row(2, 'Nguyễn Văn An', hours: 2, net: 50000), row(3, 'Trần Thị Bình')],
        'totalHours': 2, 'totalPenalty': 0, 'totalNetPay': 50000, 'totalGrossPay': 50000, 'totalSuspicious': 0, 'totalSuspiciousPay': 0,
      };
    }
    return {'month': month, 'rows': [], 'totalHours': 0, 'totalPenalty': 0, 'totalNetPay': 0, 'totalGrossPay': 0, 'totalSuspicious': 0, 'totalSuspiciousPay': 0};
  }

  ({int status, Object? body}) _handle(RequestOptions o) {
    final seg = o.path.split('/').where((s) => s.isNotEmpty).toList();
    final body = (o.data is Map ? o.data : <String, dynamic>{}) as Map;
    switch (seg[1]) {
      case 'Users':
        return (
          status: 200,
          body: [
            {'id': 1, 'email': 'admin@timeguard.local', 'username': 'admin', 'fullName': 'Quản trị viên', 'role': 'admin', 'hourlyRate': 0, 'isLocked': false},
            {'id': 2, 'email': 'an@x.com', 'username': 'an', 'fullName': 'Nguyễn Văn An', 'role': 'employee', 'hourlyRate': 30000, 'isLocked': false},
            {'id': 3, 'email': 'binh@x.com', 'username': 'binh', 'fullName': 'Trần Thị Bình', 'role': 'employee', 'hourlyRate': 30000, 'isLocked': false},
          ]
        );
      case 'Shifts':
      case 'Leaves':
        return (status: 200, body: []);
      case 'Settings':
        return (status: 200, body: {'latitude': 10.7769, 'longitude': 106.7009, 'radiusMeters': 100, 'latePenaltyPerMinute': 1000});
      case 'Reports':
        final month = o.queryParameters['month'] as String;
        if (seg.length > 3) {
          final uid = int.parse(seg[3]);
          final r = (report(month)['rows'] as List).cast<Map<String, dynamic>>().firstWhere((x) => x['userId'] == uid, orElse: () => row(uid, 'Không có'));
          final withDays = Map<String, dynamic>.from(r);
          if (month == monthKey(thisMonth) && uid == 2) {
            withDays['days'] = [
              {'date': '${isoDay(thisMonth)}T00:00:00', 'hours': 3.5, 'lateMinutes': 20, 'penalty': 20000, 'pay': 100000, 'status': 'suspicious'},
              {'date': '${isoDay(thisMonth)}T00:00:00', 'hours': 1, 'lateMinutes': 0, 'penalty': 0, 'pay': 30000, 'status': 'on-time'},
              {'date': '${isoDay(DateTime(thisMonth.year, thisMonth.month, 3))}T00:00:00', 'hours': 4, 'lateMinutes': 10, 'penalty': 10000, 'pay': 110000, 'status': 'late'},
            ];
          }
          return (status: 200, body: {'month': month, 'rows': [withDays]});
        }
        return (status: 200, body: report(month));
      case 'Attendances':
        if (o.method == 'GET') {
          final q = o.queryParameters;
          var list = records.where((r) => (q['userId'] == null || '${r['userId']}' == '${q['userId']}') && (q['status'] == null || r['status'] == q['status'])).toList();
          final from = q['from'] as String?;
          final to = q['to'] as String?;
          list = list.where((r) {
            final d = (r['workDate'] as String).substring(0, 10);
            return (from == null || d.compareTo(from) >= 0) && (to == null || d.compareTo(to) <= 0);
          }).toList();
          return (status: 200, body: list);
        }
        final rec = records.where((r) => '${r['id']}' == seg[2]).firstOrNull;
        if (rec == null) return (status: 404, body: null);
        if (seg[3] == 'review') {
          if (rec['status'] != 'suspicious') return (status: 409, body: {'success': false, 'message': 'Bản ghi này không bị đánh dấu nghi ngờ'});
          rec['status'] = (rec['lateMinutes'] as int) > 0 ? 'late' : 'on-time';
          rec['adminAction'] = 'reviewed';
          rec['adminNote'] = body['note'];
          return (status: 200, body: {'success': true, 'message': 'Đã gỡ cờ nghi ngờ', 'attendance': rec});
        }
        if (closeError != null) return (status: 400, body: {'success': false, 'message': closeError});
        rec['checkOutAt'] = '${(rec['workDate'] as String).substring(0, 10)}T05:00:00Z';
        rec['workedHours'] = 4;
        rec['pay'] = 120000;
        rec['adminAction'] = 'closed';
        rec['adminNote'] = body['note'] ?? 'Admin đóng ca quên check-out';
        return (status: 200, body: {'success': true, 'message': 'Đã đóng ca', 'attendance': rec});
    }
    return (status: 404, body: null);
  }
}

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

Future<FakeReportsBackend> openReports(WidgetTester tester, {FakeReportsBackend? backend}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final fake = backend ?? FakeReportsBackend();
  final storage = FakeTokenStorage(token: makeJwt(role: 'admin', name: 'admin', userId: 1), fullName: 'Quản trị viên');
  final t = buildTestApp(storage, fake.adapter);
  await t.auth.init();
  await tester.pumpWidget(t.app);
  await settle(tester);
  await openTab(tester, 'Báo cáo');
  return fake;
}

List<double> barValues(WidgetTester tester, String chartKey) {
  final chart = tester.widget<BarChart>(find.descendant(of: find.byKey(Key(chartKey)), matching: find.byType(BarChart)));
  return chart.data.barGroups.map((g) => g.barRods.first.toY).toList();
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('Tab Báo cáo (admin)', () {
    testWidgets('NavigationBar có 5 tab; hiện thẻ tổng và banner nghi ngờ (kèm tiền đang nghi ngờ)', (tester) async {
      final fake = await openReports(tester);
      for (final label in ['Nhân viên', 'Ca làm', 'Nghỉ phép', 'Cấu hình', 'Báo cáo']) {
        expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
      }
      expect(find.text('Tháng ${fake.thisMonth.month}/${fake.thisMonth.year}'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('total_hours')), matching: find.textContaining('11,5')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('total_pay')), matching: find.textContaining('330.000')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('total_penalty')), matching: find.textContaining('20.000')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('total_suspicious')), matching: find.text('1')), findsOneWidget);
      expect(find.textContaining('120.000'), findsWidgets);
      expect(find.byKey(const Key('report_suspicious_banner')), findsOneWidget);
    });

    testWidgets('biểu đồ cột: lương và giờ theo từng nhân viên đúng số liệu', (tester) async {
      await openReports(tester);
      expect(barValues(tester, 'chart_pay'), [230000, 100000]);
      expect(barValues(tester, 'chart_hours'), [7.5, 4]);
      // nhãn trục X là tên gọi (từ cuối của họ tên)
      expect(find.text('An'), findsWidgets);
      expect(find.text('Bình'), findsWidgets);
    });

    testWidgets('chọn tháng trước: gọi đúng month, số liệu và biểu đồ đổi; tháng sau bị khóa ở tháng hiện tại', (tester) async {
      final fake = await openReports(tester);
      expect(tester.widget<IconButton>(find.byKey(const Key('month_next'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('month_prev')));
      await settle(tester);
      expect(fake.adapter.requests.any((r) => r.path == '/api/Reports/monthly' && r.queryParameters['month'] == monthKey(fake.prevMonth)), true);
      expect(find.text('Tháng ${fake.prevMonth.month}/${fake.prevMonth.year}'), findsOneWidget);
      expect(barValues(tester, 'chart_pay'), [50000, 0]);
      expect(find.byKey(const Key('report_suspicious_banner')), findsNothing);
      expect(tester.widget<IconButton>(find.byKey(const Key('month_next'))).onPressed, isNotNull);
    });

    testWidgets('tháng không có nhân viên -> trạng thái rỗng', (tester) async {
      await openReports(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(const Key('month_prev')));
        await settle(tester);
      }
      expect(find.text('Chưa có nhân viên để báo cáo'), findsOneWidget);
    });

    testWidgets('bấm nhân viên: chi tiết có biểu đồ giờ theo ngày (gộp cùng ngày) và bảng từng ngày', (tester) async {
      final fake = await openReports(tester);
      await tester.ensureVisible(find.byKey(const Key('report_row_2')));
      await tester.tap(find.byKey(const Key('report_row_2')));
      await settle(tester);
      expect(find.byType(ReportDetailScreen), findsOneWidget);
      expect(fake.adapter.requests.any((r) => r.path == '/api/Reports/monthly/2'), true);
      expect(tester.widget<Text>(find.byKey(const Key('detail_net_pay'))).data, contains('230.000'));

      // ngày 1 có 2 bản ghi (3.5h + 1h) -> gộp thành 4.5h; ngày 3 = 4h
      final values = barValues(tester, 'detail_hours_chart');
      final lastDay = DateTime(fake.thisMonth.year, fake.thisMonth.month + 1, 0).day;
      expect(values.length, lastDay);
      expect(values[0], 4.5);
      expect(values[1], 0);
      expect(values[2], 4);

      final table = tester.widget<DataTable>(find.byKey(const Key('detail_table')));
      expect(table.rows.length, 3);
      expect(find.text('Nghi ngờ'), findsWidgets);
    });

    testWidgets('bấm "Xử lý" ở banner mở quản lý chấm công đã lọc Nghi ngờ trong tháng đang xem', (tester) async {
      final fake = await openReports(tester);
      await tester.ensureVisible(find.byKey(const Key('report_review_suspicious')));
      await tester.tap(find.byKey(const Key('report_review_suspicious')));
      await settle(tester);
      expect(find.byType(AttendancesAdminScreen), findsOneWidget);
      final req = fake.adapter.requests.lastWhere((r) => r.method == 'GET' && r.path == '/api/Attendances');
      expect(req.queryParameters['status'], 'suspicious');
      expect(req.queryParameters['from'], isoDay(fake.thisMonth));
      expect(req.queryParameters['to'], isoDay(DateTime(fake.thisMonth.year, fake.thisMonth.month + 1, 0)));
      expect(find.byKey(const Key('att_card_1')), findsOneWidget);
      expect(find.byKey(const Key('att_card_3')), findsNothing);
    });
  });

  group('Quản lý chấm công (admin)', () {
    Future<FakeReportsBackend> openAttendances(WidgetTester tester, {FakeReportsBackend? backend}) async {
      final fake = await openReports(tester, backend: backend);
      await tester.ensureVisible(find.byKey(const Key('report_open_attendances')));
      await tester.tap(find.byKey(const Key('report_open_attendances')));
      await settle(tester);
      return fake;
    }

    testWidgets('lọc theo trạng thái, chưa check-out và nhân viên', (tester) async {
      final fake = await openAttendances(tester);
      expect(find.byKey(const Key('att_card_1')), findsOneWidget);
      expect(find.byKey(const Key('att_card_2')), findsOneWidget);
      expect(find.byKey(const Key('att_card_3')), findsOneWidget);

      await tester.tap(find.byKey(const Key('att_chip_suspicious')));
      await settle(tester);
      expect(fake.adapter.requests.lastWhere((r) => r.path == '/api/Attendances').queryParameters['status'], 'suspicious');
      expect(find.byKey(const Key('att_card_1')), findsOneWidget);
      expect(find.byKey(const Key('att_card_3')), findsNothing);

      await tester.tap(find.byKey(const Key('att_chip_late')));
      await settle(tester);
      expect(find.byKey(const Key('att_card_3')), findsOneWidget);
      expect(find.byKey(const Key('att_card_1')), findsNothing);

      await tester.tap(find.byKey(const Key('att_chip_open')));
      await settle(tester);
      final req = fake.adapter.requests.lastWhere((r) => r.path == '/api/Attendances');
      expect(req.queryParameters.containsKey('status'), false, reason: 'lọc chưa check-out làm phía client');
      expect(find.byKey(const Key('att_card_2')), findsOneWidget);
      expect(find.byKey(const Key('att_card_1')), findsNothing);

      await tester.tap(find.byKey(const Key('att_chip_all')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('att_filter_user')));
      await settle(tester);
      await tester.tap(find.text('Trần Thị Bình').last);
      await settle(tester);
      expect(fake.adapter.requests.lastWhere((r) => r.path == '/api/Attendances').queryParameters['userId'], 3);
      expect(find.byKey(const Key('att_card_2')), findsOneWidget);
      expect(find.byKey(const Key('att_card_1')), findsNothing);
    });

    testWidgets('gỡ cờ nghi ngờ: nút chỉ có ở bản ghi nghi ngờ; gửi ghi chú; thẻ cập nhật', (tester) async {
      final fake = await openAttendances(tester);
      expect(find.byKey(const Key('att_review_1')), findsOneWidget);
      expect(find.byKey(const Key('att_review_2')), findsNothing);
      expect(find.byKey(const Key('att_review_3')), findsNothing);

      await tester.tap(find.byKey(const Key('att_review_1')));
      await settle(tester);
      expect(find.text('Gỡ cờ nghi ngờ?'), findsOneWidget);
      expect(find.textContaining('GPS giả (mock location)'), findsWidgets);
      await tester.enterText(find.byKey(const Key('review_note')), 'Đã gọi điện xác nhận');
      await tester.tap(find.byKey(const Key('review_confirm')));
      await settle(tester);

      final put = fake.adapter.requests.firstWhere((r) => r.method == 'PUT' && r.path == '/api/Attendances/1/review');
      expect((put.data as Map)['note'], 'Đã gọi điện xác nhận');
      expect(find.byKey(const Key('att_review_1')), findsNothing);
      expect(find.textContaining('Admin đã gỡ cờ nghi ngờ: Đã gọi điện xác nhận'), findsOneWidget);
      expect(find.text('Đi trễ'), findsWidgets); // còn LateMinutes > 0 nên chuyển về "Đi trễ"
    });

    testWidgets('đóng ca quên check-out: mặc định giờ ra = giờ hết ca, gửi HH:mm', (tester) async {
      final fake = await openAttendances(tester);
      expect(find.byKey(const Key('att_close_2')), findsOneWidget);
      expect(find.byKey(const Key('att_close_1')), findsNothing);

      await tester.tap(find.byKey(const Key('att_close_2')));
      await settle(tester);
      expect(find.text('Đóng ca quên check-out'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('close_time_text'))).data, 'Giờ ra: 12:00');
      await tester.enterText(find.byKey(const Key('close_note')), 'Quên bấm ra');
      await tester.tap(find.byKey(const Key('close_confirm')));
      await settle(tester);

      final put = fake.adapter.requests.firstWhere((r) => r.method == 'PUT' && r.path == '/api/Attendances/2/close');
      expect((put.data as Map)['checkOutTime'], '12:00');
      expect((put.data as Map)['note'], 'Quên bấm ra');
      expect(find.byKey(const Key('att_close_2')), findsNothing);
      expect(find.textContaining('Admin đã đóng ca: Quên bấm ra'), findsOneWidget);
    });

    testWidgets('đóng ca bị server từ chối: hiện lý do, bản ghi vẫn mở', (tester) async {
      final fake = FakeReportsBackend()..closeError = 'Giờ ra phải sau giờ vào (08:03)';
      await openAttendances(tester, backend: fake);
      await tester.tap(find.byKey(const Key('att_close_2')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('close_confirm')));
      await settle(tester);
      expect(find.text('Giờ ra phải sau giờ vào (08:03)'), findsOneWidget);
      expect(find.byKey(const Key('att_close_2')), findsOneWidget);
    });

    testWidgets('quay về tab Báo cáo thì báo cáo được tải lại', (tester) async {
      final fake = await openAttendances(tester);
      final before = fake.adapter.requests.where((r) => r.path == '/api/Reports/monthly').length;
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(fake.adapter.requests.where((r) => r.path == '/api/Reports/monthly').length, before + 1);
    });
  });

  group('Biểu đồ giờ làm', () {
    testWidgets('gộp bản ghi cùng ngày, tô màu theo trạng thái xấu nhất, tooltip có nội dung', (tester) async {
      late List<BarPoint> bars;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          bars = HoursByDayChart.buildBars(context, [
            DailyReportItem(date: DateTime(2026, 10, 5), hours: 2, lateMinutes: 0, penalty: 0, pay: 0, status: 'on-time'),
            DailyReportItem(date: DateTime(2026, 10, 5), hours: 1.5, lateMinutes: 10, penalty: 0, pay: 0, status: 'suspicious'),
            DailyReportItem(date: DateTime(2026, 10, 6), hours: 4, lateMinutes: 0, penalty: 0, pay: 0, status: 'on-time'),
            DailyReportItem(date: DateTime(2026, 9, 30), hours: 9, lateMinutes: 0, penalty: 0, pay: 0, status: 'on-time'), // khác tháng -> bỏ
          ], DateTime(2026, 10));
          return const SizedBox();
        }),
      ));
      expect(bars.length, 31);
      expect(bars[4].value, 3.5);
      expect(bars[4].color, isNotNull, reason: 'có ca nghi ngờ -> màu cảnh báo');
      expect(bars[5].value, 4);
      expect(bars[5].color, isNull);
      expect(bars[0].value, 0);
      expect(bars[4].tooltip, contains('Nghi ngờ'));
    });

    testWidgets('không có dữ liệu -> hiện dòng thông báo thay vì biểu đồ trống', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SimpleBarChart(bars: const [], axisFormatter: Fmt.compactMoney))));
      expect(find.text('Chưa có dữ liệu để vẽ biểu đồ'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });
  });
}
