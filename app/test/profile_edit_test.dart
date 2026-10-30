import 'package:buidoananhviet/models/app_user.dart';
import 'package:buidoananhviet/screens/employee/profile_edit_screen.dart';
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

Future<FakeEmployeeBackend> openEdit(WidgetTester tester, {FakeEmployeeBackend? backend}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final fake = backend ?? FakeEmployeeBackend();
  final t = buildTestApp(FakeTokenStorage(token: makeJwt(), fullName: 'Nguyễn Văn An'), fake.adapter);
  await t.auth.init();
  await tester.pumpWidget(t.app);
  await settle(tester);
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Hồ sơ')));
  await settle(tester);
  await tester.ensureVisible(find.byKey(const Key('profile_edit')));
  await tester.tap(find.byKey(const Key('profile_edit')));
  await settle(tester);
  return fake;
}

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('Kiểm tra hợp lệ phía app', () {
    test('SĐT: hợp lệ/không hợp lệ/để trống', () {
      expect(ProfileValidators.phone(''), isNull);
      expect(ProfileValidators.phone(null), isNull);
      expect(ProfileValidators.phone('0912345678'), isNull);
      expect(ProfileValidators.phone('+84 912 345 678'), isNull);
      expect(ProfileValidators.normalizePhone('+84912345678'), '0912345678');
      expect(ProfileValidators.phone('12345'), isNotNull);
      expect(ProfileValidators.phone('0112345678'), isNotNull);
    });

    test('địa chỉ <= 200 ký tự, họ tên không rỗng', () {
      expect(ProfileValidators.address('a' * 200), isNull);
      expect(ProfileValidators.address('a' * 201), 'Địa chỉ tối đa 200 ký tự');
      expect(ProfileValidators.fullName('  '), 'Họ và tên không được để trống');
      expect(ProfileValidators.fullName('An'), isNull);
    });

    test('AppUser đọc các trường hồ sơ mới; thiếu/rỗng thì null (tương thích bản cũ)', () {
      final u = AppUser.fromJson({'id': 2, 'fullName': 'An', 'phone': '0912345678', 'dateOfBirth': '2000-05-20T00:00:00', 'address': '12 Lê Lợi'});
      expect(u.phone, '0912345678');
      expect(u.dateOfBirth, DateTime(2000, 5, 20));
      expect(u.address, '12 Lê Lợi');
      final old = AppUser.fromJson({'id': 2, 'fullName': 'An', 'phone': '', 'address': null});
      expect((old.phone, old.dateOfBirth, old.address), (null, null, null));
    });
  });

  group('Màn Sửa hồ sơ', () {
    testWidgets('lưu họ tên + SĐT + địa chỉ: gửi đúng PUT, hồ sơ cập nhật và hiển thị', (tester) async {
      final fake = await openEdit(tester);
      expect(find.text('Sửa hồ sơ'), findsWidgets);
      await tester.enterText(field('pe_name'), 'Nguyễn An Khang');
      await tester.enterText(field('pe_phone'), '+84 912 345 678');
      await tester.enterText(field('pe_address'), '45 Trần Hưng Đạo, Q1');
      await tester.ensureVisible(find.byKey(const Key('pe_save')));
      await tester.tap(find.byKey(const Key('pe_save')));
      await settle(tester);

      final put = fake.adapter.requests.lastWhere((r) => r.path == '/api/Users/me' && r.method == 'PUT');
      final body = put.data as Map;
      expect(body['fullName'], 'Nguyễn An Khang');
      expect(body['phone'], '0912345678'); // đã chuẩn hóa
      expect(body['address'], '45 Trần Hưng Đạo, Q1');
      expect(body['dateOfBirth'], '');
      // quay lại Hồ sơ: hiện thông tin mới
      expect(find.text('Nguyễn An Khang'), findsWidgets);
      expect(find.text('0912345678'), findsOneWidget);
      expect(find.text('45 Trần Hưng Đạo, Q1'), findsOneWidget);
    });

    testWidgets('SĐT sai: báo lỗi, không gọi API', (tester) async {
      final fake = await openEdit(tester);
      final before = fake.adapter.requests.where((r) => r.method == 'PUT').length;
      await tester.enterText(field('pe_phone'), '12345');
      await tester.ensureVisible(find.byKey(const Key('pe_save')));
      await tester.tap(find.byKey(const Key('pe_save')));
      await settle(tester);
      expect(find.text('Số điện thoại không hợp lệ (ví dụ 0912345678)'), findsOneWidget);
      expect(fake.adapter.requests.where((r) => r.method == 'PUT').length, before);
    });

    testWidgets('họ tên trống và địa chỉ quá 200 ký tự bị chặn', (tester) async {
      await openEdit(tester);
      await tester.enterText(field('pe_name'), '   ');
      await tester.ensureVisible(find.byKey(const Key('pe_save')));
      await tester.tap(find.byKey(const Key('pe_save')));
      await settle(tester);
      expect(find.text('Họ và tên không được để trống'), findsOneWidget);
    });

    testWidgets('xóa SĐT bằng cách để trống: gửi chuỗi rỗng', (tester) async {
      final fake = FakeEmployeeBackend()..me['phone'] = '0912345678';
      await openEdit(tester, backend: fake);
      expect(find.text('0912345678'), findsWidgets); // đang có sẵn trong ô nhập (và ở thẻ hồ sơ phía sau)
      await tester.enterText(field('pe_phone'), '');
      await tester.ensureVisible(find.byKey(const Key('pe_save')));
      await tester.tap(find.byKey(const Key('pe_save')));
      await settle(tester);
      final body = fake.adapter.requests.lastWhere((r) => r.method == 'PUT' && r.path == '/api/Users/me').data as Map;
      expect(body['phone'], '');
      expect(fake.me['phone'], isNull);
    });

    testWidgets('lỗi server (400) hiện đúng lời server và ở lại màn sửa', (tester) async {
      final fake = await openEdit(tester);
      fake.adapter.interceptor = (o) => (o.method == 'PUT' && o.path == '/api/Users/me')
          ? (status: 400, body: {'success': false, 'message': 'Số điện thoại không hợp lệ (ví dụ 0912345678)'})
          : null;
      await tester.enterText(field('pe_phone'), '0912345678');
      await tester.ensureVisible(find.byKey(const Key('pe_save')));
      await tester.tap(find.byKey(const Key('pe_save')));
      await settle(tester);
      expect(find.text('Số điện thoại không hợp lệ (ví dụ 0912345678)'), findsOneWidget);
      expect(find.byKey(const Key('pe_save')), findsOneWidget);
    });
  });
}
