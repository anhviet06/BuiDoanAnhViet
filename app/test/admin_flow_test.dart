import 'package:buidoananhviet/screens/admin/user_form_screen.dart';
import 'package:buidoananhviet/services/location_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'helpers.dart';

/// Backend giả có trạng thái cho các màn admin. Admin đang đăng nhập có id = 1.
class FakeAdminBackend {
  final users = <Map<String, dynamic>>[
    _user(1, 'Quản trị viên', 'admin@timeguard.local', 'admin', 'admin', 0),
    _user(2, 'Nguyễn Văn An', 'an.nguyen@timeguard.local', 'annguyen', 'employee', 30000),
    _user(3, 'Trần Thị Bình', 'binh.tran@timeguard.local', 'binhtran', 'employee', 35000),
  ];
  final shifts = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Ca sáng', 'startTime': '08:00:00', 'endTime': '12:00:00', 'lateGraceMinutes': 5, 'qrToken': 'token-sang-1', 'isActive': true},
    {'id': 2, 'name': 'Ca chiều', 'startTime': '13:30:00', 'endTime': '17:30:00', 'lateGraceMinutes': 10, 'qrToken': 'token-chieu-1', 'isActive': true},
  ];
  final leaves = <Map<String, dynamic>>[
    {'id': 1, 'userId': 2, 'user': null, 'fromDate': '2026-11-10T00:00:00', 'toDate': '2026-11-12T00:00:00', 'reason': 'Việc gia đình', 'status': 'pending', 'adminNote': null, 'createdAt': '2026-10-29T01:00:00Z'},
    {'id': 2, 'userId': 3, 'user': null, 'fromDate': '2026-12-01T00:00:00', 'toDate': '2026-12-01T00:00:00', 'reason': 'Khám bệnh', 'status': 'approved', 'adminNote': 'OK', 'createdAt': '2026-10-28T01:00:00Z'},
  ];
  Map<String, dynamic> company = {'latitude': 10.7769, 'longitude': 106.7009, 'radiusMeters': 100, 'latePenaltyPerMinute': 1000};
  bool failShifts = false;
  var _qr = 1;
  late final FakeBackend adapter = FakeBackend(_handle);

  static Map<String, dynamic> _user(int id, String name, String email, String username, String role, num rate) => {
        'id': id,
        'email': email,
        'username': username,
        'fullName': name,
        'role': role,
        'hourlyRate': rate,
        'isLocked': false,
        'createdAt': '2026-10-29T01:00:00Z',
      };

  Map<String, dynamic>? _find(List<Map<String, dynamic>> list, String id) {
    for (final e in list) {
      if ('${e['id']}' == id) return e;
    }
    return null;
  }

  ({int status, Object? body}) _handle(RequestOptions o) {
    final seg = o.path.split('/').where((s) => s.isNotEmpty).toList(); // [api, Users, 3, lock]
    final body = (o.data is Map ? o.data : <String, dynamic>{}) as Map;
    const ok = (status: 204, body: null);
    final id = seg.length > 2 ? seg[2] : '';
    switch (seg[1]) {
      case 'Users':
        if (o.method == 'GET') return (status: 200, body: users);
        if (o.method == 'POST') {
          if (users.any((u) => u['email'] == body['email'])) {
            return (status: 400, body: {'success': false, 'message': 'Email hoặc tên đăng nhập đã tồn tại'});
          }
          final u = _user(users.length + 10, body['fullName'], body['email'], body['username'], body['role'], body['hourlyRate']);
          users.add(u);
          return (status: 201, body: u);
        }
        final user = _find(users, id);
        if (user == null) return (status: 404, body: null);
        if (o.method == 'DELETE') {
          if (id == '3') {
            return (status: 409, body: {'success': false, 'message': 'Nhân viên đã có dữ liệu chấm công, không thể xóa. Hãy khóa tài khoản.'});
          }
          users.remove(user);
          return ok;
        }
        if (seg.length > 3 && seg[3] == 'lock') {
          user['isLocked'] = body['isLocked'];
        } else if (seg.length > 3 && seg[3] == 'password') {
          // không lưu
        } else {
          user..['email'] = body['email']..['username'] = body['username']..['fullName'] = body['fullName']..['hourlyRate'] = body['hourlyRate']..['role'] = body['role'];
        }
        return ok;
      case 'Shifts':
        if (failShifts) return (status: 500, body: 'Internal server error');
        if (o.method == 'GET') return (status: 200, body: shifts);
        if (o.method == 'POST' && seg.length == 2) {
          final s = {'id': shifts.length + 10, 'name': body['name'], 'startTime': '${body['startTime']}:00', 'endTime': '${body['endTime']}:00', 'lateGraceMinutes': body['lateGraceMinutes'], 'qrToken': 'token-moi', 'isActive': body['isActive']};
          shifts.add(s);
          return (status: 201, body: s);
        }
        final shift = _find(shifts, id);
        if (shift == null) return (status: 404, body: null);
        if (seg.length > 3 && seg[3] == 'regenerate-qr') {
          shift['qrToken'] = 'token-doi-${++_qr}';
          return (status: 200, body: shift);
        }
        if (o.method == 'DELETE') {
          if (id == '1') {
            return (status: 409, body: {'success': false, 'message': 'Ca đã có dữ liệu chấm công, không thể xóa. Hãy tắt hoạt động của ca.'});
          }
          shifts.remove(shift);
          return ok;
        }
        shift..['name'] = body['name']..['startTime'] = '${body['startTime']}:00'..['endTime'] = '${body['endTime']}:00'..['lateGraceMinutes'] = body['lateGraceMinutes']..['isActive'] = body['isActive'];
        return ok;
      case 'Leaves':
        if (o.method == 'GET') {
          final status = o.queryParameters['status'];
          final list = leaves.where((l) => status == null || l['status'] == status).map((l) {
            final u = _find(users, '${l['userId']}');
            return {...l, 'user': u};
          }).toList();
          return (status: 200, body: list);
        }
        final leave = _find(leaves, id);
        if (leave == null) return (status: 404, body: null);
        if (leave['status'] != 'pending') return (status: 409, body: {'success': false, 'message': 'Đơn này đã được xử lý'});
        leave['status'] = seg[3] == 'approve' ? 'approved' : 'rejected';
        leave['adminNote'] = body['adminNote'];
        return (status: 200, body: leave);
      case 'Settings':
        if (o.method == 'GET') return (status: 200, body: company);
        company = Map<String, dynamic>.from(body);
        return ok;
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

Future<FakeAdminBackend> openAdmin(WidgetTester tester, {LocationService? location, FakeAdminBackend? backend}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final fake = backend ?? FakeAdminBackend();
  final storage = FakeTokenStorage(token: makeJwt(role: 'admin', name: 'admin', userId: 1), fullName: 'Quản trị viên');
  final t = buildTestApp(storage, fake.adapter, location: location);
  await t.auth.init();
  await tester.pumpWidget(t.app);
  await settle(tester);
  return fake;
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('Khung admin + tab Nhân viên', () {
    testWidgets('NavigationBar 4 tab, danh sách nhân viên hiển thị đủ', (tester) async {
      await openAdmin(tester);
      final nav = find.byType(NavigationBar);
      for (final label in ['Nhân viên', 'Ca làm', 'Nghỉ phép', 'Cấu hình']) {
        expect(find.descendant(of: nav, matching: find.text(label)), findsOneWidget);
      }
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('Trần Thị Bình'), findsOneWidget);
      expect(find.text('Quản trị viên (bạn)'), findsOneWidget);
      expect(find.textContaining('30.000'), findsOneWidget);
    });

    testWidgets('tìm kiếm lọc danh sách, không thấy thì báo rỗng', (tester) async {
      await openAdmin(tester);
      await tester.enterText(field('users_search'), 'bình');
      await tester.pump();
      expect(find.text('Trần Thị Bình'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsNothing);
      await tester.enterText(field('users_search'), 'zzzz');
      await tester.pump();
      expect(find.text('Không tìm thấy kết quả'), findsOneWidget);
    });

    testWidgets('thêm nhân viên: validate rồi lưu, danh sách cập nhật', (tester) async {
      final fake = await openAdmin(tester);
      await tester.tap(find.byKey(const Key('users_add')));
      await settle(tester);
      expect(find.byType(UserFormScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('uf_submit')));
      await tester.pump();
      expect(find.text('Họ và tên không được để trống'), findsOneWidget);
      expect(find.text('Email không được để trống'), findsOneWidget);
      expect(find.text('Mật khẩu không được để trống'), findsOneWidget);

      await tester.enterText(field('uf_name'), 'Lê Văn Cường');
      await tester.enterText(field('uf_email'), 'cuong@x.com');
      await tester.enterText(field('uf_username'), 'cuong');
      await tester.enterText(field('uf_password'), 'abc123');
      await tester.enterText(field('uf_rate'), '45000');
      await tester.tap(find.byKey(const Key('uf_submit')));
      await settle(tester);

      expect(find.byType(UserFormScreen), findsNothing);
      expect(find.text('Lê Văn Cường'), findsOneWidget);
      final posted = fake.adapter.requests.firstWhere((r) => r.method == 'POST' && r.path == '/api/Users').data as Map;
      expect(posted['password'], 'abc123');
      expect(posted['hourlyRate'], 45000);
      expect(posted['role'], 'employee');
    });

    testWidgets('email trùng: hiện lỗi server, ở lại form', (tester) async {
      await openAdmin(tester);
      await tester.tap(find.byKey(const Key('users_add')));
      await settle(tester);
      await tester.enterText(field('uf_name'), 'X');
      await tester.enterText(field('uf_email'), 'an.nguyen@timeguard.local');
      await tester.enterText(field('uf_username'), 'xxx');
      await tester.enterText(field('uf_password'), 'abc123');
      await tester.tap(find.byKey(const Key('uf_submit')));
      await settle(tester);
      expect(find.text('Email hoặc tên đăng nhập đã tồn tại'), findsOneWidget);
      expect(find.byType(UserFormScreen), findsOneWidget);
    });

    testWidgets('sửa nhân viên: form điền sẵn, không có ô mật khẩu, lưu gửi PUT', (tester) async {
      final fake = await openAdmin(tester);
      await tester.tap(find.text('Nguyễn Văn An'));
      await settle(tester);
      expect(find.byKey(const Key('uf_password')), findsNothing);
      expect(tester.widget<EditableText>(field('uf_name')).controller.text, 'Nguyễn Văn An');
      await tester.enterText(field('uf_rate'), '32000');
      await tester.tap(find.byKey(const Key('uf_submit')));
      await settle(tester);
      expect((fake.adapter.requests.firstWhere((r) => r.method == 'PUT' && r.path == '/api/Users/2').data as Map)['hourlyRate'], 32000);
      expect(find.textContaining('32.000'), findsOneWidget);
    });

    testWidgets('khóa rồi mở khóa tài khoản (có xác nhận)', (tester) async {
      final fake = await openAdmin(tester);
      await tester.tap(find.byKey(const Key('user_menu_2')));
      await settle(tester);
      await tester.tap(find.text('Khóa tài khoản'));
      await settle(tester);
      expect(find.text('Khóa tài khoản?'), findsOneWidget);
      await tester.tap(find.text('Khóa').last);
      await settle(tester);
      expect(fake.users[1]['isLocked'], true);
      expect(find.text('Đã khóa'), findsOneWidget);

      await tester.tap(find.byKey(const Key('user_menu_2')));
      await settle(tester);
      await tester.tap(find.text('Mở khóa'));
      await settle(tester);
      await tester.tap(find.text('Mở khóa').last);
      await settle(tester);
      expect(fake.users[1]['isLocked'], false);
    });

    testWidgets('chính mình: không có Khóa/Xóa trong menu', (tester) async {
      await openAdmin(tester);
      await tester.tap(find.byKey(const Key('user_menu_1')));
      await settle(tester);
      expect(find.text('Sửa thông tin'), findsOneWidget);
      expect(find.text('Đặt lại mật khẩu'), findsOneWidget);
      expect(find.text('Khóa tài khoản'), findsNothing);
      expect(find.text('Xóa'), findsNothing);
    });

    testWidgets('xóa nhân viên chưa chấm công -> biến mất khỏi danh sách', (tester) async {
      final fake = await openAdmin(tester);
      await tester.tap(find.byKey(const Key('user_menu_2')));
      await settle(tester);
      await tester.tap(find.text('Xóa'));
      await settle(tester);
      await tester.tap(find.text('Xóa').last);
      await settle(tester);
      expect(fake.users.any((u) => u['id'] == 2), false);
      expect(find.text('Nguyễn Văn An'), findsNothing);
    });

    testWidgets('xóa nhân viên đã có chấm công -> 409, gợi ý Khóa và khóa được', (tester) async {
      final fake = await openAdmin(tester);
      await tester.tap(find.byKey(const Key('user_menu_3')));
      await settle(tester);
      await tester.tap(find.text('Xóa'));
      await settle(tester);
      await tester.tap(find.text('Xóa').last);
      await settle(tester);
      expect(find.text('Không thể xóa'), findsOneWidget);
      expect(find.textContaining('Hãy khóa tài khoản'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_conflict_lock')));
      await settle(tester);
      expect(fake.users.any((u) => u['id'] == 3), true);
      expect(fake.users[2]['isLocked'], true);
    });

    testWidgets('đặt lại mật khẩu: validate độ dài rồi gửi', (tester) async {
      final fake = await openAdmin(tester);
      await tester.tap(find.byKey(const Key('user_menu_2')));
      await settle(tester);
      await tester.tap(find.text('Đặt lại mật khẩu'));
      await settle(tester);
      await tester.enterText(field('reset_password_field'), '123');
      await tester.tap(find.byKey(const Key('reset_password_submit')));
      await tester.pump();
      expect(find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);
      await tester.enterText(field('reset_password_field'), 'moi12345');
      await tester.tap(find.byKey(const Key('reset_password_submit')));
      await settle(tester);
      final put = fake.adapter.requests.firstWhere((r) => r.path == '/api/Users/2/password');
      expect((put.data as Map)['newPassword'], 'moi12345');
    });
  });

  group('Tab Ca làm', () {
    testWidgets('danh sách ca; chi tiết hiện QR chứa đúng qrToken + mã nhập tay', (tester) async {
      await openAdmin(tester);
      await openTab(tester, 'Ca làm');
      expect(find.text('Ca sáng'), findsOneWidget);
      expect(find.text('08:00 - 12:00'), findsOneWidget);
      expect(find.text('Ân hạn 10 phút'), findsOneWidget);

      await tester.tap(find.byKey(const Key('shift_card_1')));
      await settle(tester);
      expect(find.byKey(const ValueKey('shift_qr:token-sang-1')), findsOneWidget);
      expect(find.text('token-sang-1'), findsOneWidget);
    });

    testWidgets('Đổi mã QR có xác nhận, QR cập nhật theo token mới', (tester) async {
      await openAdmin(tester);
      await openTab(tester, 'Ca làm');
      await tester.tap(find.byKey(const Key('shift_card_1')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('shift_regenerate')));
      await tester.tap(find.byKey(const Key('shift_regenerate')));
      await settle(tester);
      expect(find.text('Đổi mã QR?'), findsOneWidget);
      // Hủy: không đổi
      await tester.tap(find.text('Hủy'));
      await settle(tester);
      expect(find.byKey(const ValueKey('shift_qr:token-sang-1')), findsOneWidget);
      // Đồng ý
      await tester.tap(find.byKey(const Key('shift_regenerate')));
      await settle(tester);
      await tester.tap(find.text('Đổi mã'));
      await settle(tester);
      expect(find.byKey(const ValueKey('shift_qr:token-doi-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('shift_qr:token-sang-1')), findsNothing);
    });

    testWidgets('thêm ca mới', (tester) async {
      final fake = await openAdmin(tester);
      await openTab(tester, 'Ca làm');
      await tester.tap(find.byKey(const Key('shifts_add')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('sf_submit')));
      await tester.pump();
      expect(find.text('Tên ca không được để trống'), findsOneWidget);
      await tester.enterText(field('sf_name'), 'Ca tối');
      await tester.tap(find.byKey(const Key('sf_submit')));
      await settle(tester);
      final posted = fake.adapter.requests.firstWhere((r) => r.method == 'POST' && r.path == '/api/Shifts').data as Map;
      expect(posted['startTime'], '08:00');
      expect(posted['endTime'], '17:00');
      expect(posted['lateGraceMinutes'], 5);
      expect(find.text('Ca tối'), findsOneWidget);
    });

    testWidgets('xóa ca đã có chấm công -> 409, gợi ý tạm dừng', (tester) async {
      final fake = await openAdmin(tester);
      await openTab(tester, 'Ca làm');
      await tester.tap(find.byKey(const Key('shift_card_1')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('shift_delete')));
      await settle(tester);
      await tester.tap(find.text('Xóa').last);
      await settle(tester);
      expect(find.text('Không thể xóa'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_conflict_pause')));
      await settle(tester);
      expect(fake.shifts.first['isActive'], false);
      expect(find.textContaining('Tạm dừng'), findsWidgets);
    });

    testWidgets('xóa ca chưa có chấm công -> về danh sách', (tester) async {
      final fake = await openAdmin(tester);
      await openTab(tester, 'Ca làm');
      await tester.tap(find.byKey(const Key('shift_card_2')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('shift_delete')));
      await settle(tester);
      await tester.tap(find.text('Xóa').last);
      await settle(tester);
      expect(fake.shifts.length, 1);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Ca chiều'), findsNothing);
    });

    testWidgets('lỗi server -> màn lỗi có nút Thử lại; sửa xong bấm Thử lại thì tải được', (tester) async {
      final fake = FakeAdminBackend()..failShifts = true;
      await openAdmin(tester, backend: fake);
      await openTab(tester, 'Ca làm');
      expect(find.text('Internal server error'), findsOneWidget);
      fake.failShifts = false;
      await tester.tap(find.text('Thử lại'));
      await settle(tester);
      expect(find.text('Ca sáng'), findsOneWidget);
    });

    testWidgets('chưa có ca nào -> màn rỗng', (tester) async {
      final fake = FakeAdminBackend()..shifts.clear();
      await openAdmin(tester, backend: fake);
      await openTab(tester, 'Ca làm');
      expect(find.text('Chưa có ca làm việc'), findsOneWidget);
    });
  });

  group('Tab Nghỉ phép', () {
    testWidgets('mặc định lọc Chờ duyệt; duyệt đơn kèm ghi chú', (tester) async {
      final fake = await openAdmin(tester);
      await openTab(tester, 'Nghỉ phép');
      expect(find.text('Việc gia đình'), findsOneWidget);
      expect(find.text('Khám bệnh'), findsNothing);
      expect(find.text('10/11/2026 - 12/11/2026  (3 ngày)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('leave_approve_1')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('decision_note')), 'Đồng ý, nhớ bàn giao');
      await tester.tap(find.byKey(const Key('decision_confirm')));
      await settle(tester);
      final put = fake.adapter.requests.firstWhere((r) => r.path == '/api/Leaves/1/approve');
      expect((put.data as Map)['adminNote'], 'Đồng ý, nhớ bàn giao');
      expect(find.text('Không có đơn chờ duyệt'), findsOneWidget);

      await tester.tap(find.byKey(const Key('leave_filter_approved')));
      await settle(tester);
      expect(find.text('Việc gia đình'), findsOneWidget);
      expect(find.text('Khám bệnh'), findsOneWidget);
      expect(find.text('Ghi chú: Đồng ý, nhớ bàn giao'), findsOneWidget);
    });

    testWidgets('từ chối đơn không ghi chú', (tester) async {
      final fake = await openAdmin(tester);
      await openTab(tester, 'Nghỉ phép');
      await tester.tap(find.byKey(const Key('leave_reject_1')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('decision_confirm')));
      await settle(tester);
      expect(fake.leaves.first['status'], 'rejected');
      expect((fake.adapter.requests.firstWhere((r) => r.path == '/api/Leaves/1/reject').data as Map)['adminNote'], isNull);
    });

    testWidgets('bộ lọc Tất cả hiện cả đơn đã xử lý; đơn đã xử lý không có nút duyệt', (tester) async {
      await openAdmin(tester);
      await openTab(tester, 'Nghỉ phép');
      await tester.tap(find.byKey(const Key('leave_filter_all')));
      await settle(tester);
      expect(find.text('Việc gia đình'), findsOneWidget);
      expect(find.text('Khám bệnh'), findsOneWidget);
      expect(find.byKey(const Key('leave_approve_2')), findsNothing);
      expect(find.byKey(const Key('leave_approve_1')), findsOneWidget);
    });
  });

  group('Tab Cấu hình', () {
    testWidgets('hiện giá trị hiện tại; nhập tay và lưu', (tester) async {
      final fake = await openAdmin(tester);
      await openTab(tester, 'Cấu hình');
      expect(tester.widget<EditableText>(field('set_lat')).controller.text, '10.7769');
      expect(tester.widget<EditableText>(field('set_radius')).controller.text, '100');
      await tester.enterText(field('set_radius'), '150');
      await tester.enterText(field('set_penalty'), '2000');
      await tester.ensureVisible(find.byKey(const Key('set_save')));
      await tester.tap(find.byKey(const Key('set_save')));
      await settle(tester);
      expect(fake.company['radiusMeters'], 150);
      expect(fake.company['latePenaltyPerMinute'], 2000);
      expect(find.text('Đã lưu cấu hình'), findsOneWidget);
    });

    testWidgets('"Lấy vị trí hiện tại" điền vĩ độ/kinh độ, vẫn sửa tay được rồi lưu', (tester) async {
      final fake = await openAdmin(tester, location: FakeLocationService(reading: const LocationReading(21.028511, 105.804817)));
      await openTab(tester, 'Cấu hình');
      await tester.tap(find.byKey(const Key('set_locate')));
      await settle(tester);
      expect(tester.widget<EditableText>(field('set_lat')).controller.text, '21.028511');
      expect(tester.widget<EditableText>(field('set_lng')).controller.text, '105.804817');
      await tester.ensureVisible(find.byKey(const Key('set_save')));
      await tester.tap(find.byKey(const Key('set_save')));
      await settle(tester);
      expect(fake.company['latitude'], 21.028511);
      expect(fake.company['longitude'], 105.804817);
    });

    testWidgets('lấy vị trí lỗi (chưa cấp quyền) -> hiện thông báo, không đổi ô nhập', (tester) async {
      await openAdmin(tester, location: FakeLocationService(error: const LocationException('Bạn chưa cấp quyền truy cập vị trí cho ứng dụng.')));
      await openTab(tester, 'Cấu hình');
      await tester.tap(find.byKey(const Key('set_locate')));
      await settle(tester);
      expect(find.text('Bạn chưa cấp quyền truy cập vị trí cho ứng dụng.'), findsOneWidget);
      expect(tester.widget<EditableText>(field('set_lat')).controller.text, '10.7769');
    });

    testWidgets('validate: vĩ độ ngoài khoảng, bán kính rỗng; chấp nhận dấu phẩy thập phân', (tester) async {
      final fake = await openAdmin(tester);
      await openTab(tester, 'Cấu hình');
      await tester.enterText(field('set_lat'), '200');
      await tester.enterText(field('set_radius'), '');
      await tester.ensureVisible(find.byKey(const Key('set_save')));
      await tester.tap(find.byKey(const Key('set_save')));
      await tester.pump();
      expect(find.textContaining('Vĩ độ phải từ'), findsOneWidget);
      expect(find.text('Bán kính không hợp lệ'), findsOneWidget);
      expect(fake.adapter.requests.where((r) => r.method == 'PUT'), isEmpty);

      await tester.enterText(field('set_lat'), '10,5');
      await tester.enterText(field('set_radius'), '80');
      await tester.tap(find.byKey(const Key('set_save')));
      await settle(tester);
      expect(fake.company['latitude'], 10.5);
    });
  });
}
