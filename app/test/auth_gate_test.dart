import 'package:buidoananhviet/screens/auth/login_screen.dart';
import 'package:buidoananhviet/screens/employee/employee_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:buidoananhviet/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

final build = buildTestApp;

void main() {
  testWidgets('chưa có token -> màn đăng nhập', (tester) async {
    final t = build(FakeTokenStorage(), StubAdapter(200));
    await t.auth.init();
    await tester.pumpWidget(t.app);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('token role admin -> trang quản trị', (tester) async {
    final t = build(FakeTokenStorage(token: makeJwt(role: 'admin', name: 'admin'), fullName: 'Quản trị viên'), StubAdapter(200));
    await t.auth.init();
    await tester.pumpWidget(t.app);
    await tester.pump(const Duration(milliseconds: 200)); // cho các request đầu tiên của tab hoàn tất
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('token role employee -> dashboard nhân viên', (tester) async {
    final t = build(FakeTokenStorage(token: makeJwt(), fullName: 'Nguyễn Văn An'), StubAdapter(200));
    await t.auth.init();
    await tester.pumpWidget(t.app);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(EmployeeHomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('token hết hạn lúc mở app -> xóa token, về đăng nhập kèm thông báo', (tester) async {
    final storage = FakeTokenStorage(token: makeJwt(expiresIn: const Duration(minutes: -1)));
    final t = build(storage, StubAdapter(200));
    await t.auth.init();
    await tester.pumpWidget(t.app);
    expect(storage.token, isNull);
    expect(find.textContaining('hết hạn'), findsOneWidget);
  });

  testWidgets('đăng xuất -> về màn đăng nhập và xóa token', (tester) async {
    final storage = FakeTokenStorage(token: makeJwt());
    final t = build(storage, StubAdapter(200));
    await t.auth.init();
    await tester.pumpWidget(t.app);
    await tester.tap(find.byTooltip('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(storage.token, isNull);
  });

  testWidgets('server trả 401 khi đang đăng nhập -> tự xóa token và về đăng nhập', (tester) async {
    final storage = FakeTokenStorage(token: makeJwt());
    final t = build(storage, StubAdapter(401));
    await t.auth.init();
    await tester.pumpWidget(t.app);
    expect(find.byType(EmployeeHomeScreen), findsOneWidget);

    await tester.runAsync(() async {
      try {
        await t.api.get('/api/Attendances/today');
      } on ApiException catch (_) {}
    });
    await tester.pumpAndSettle();
    expect(storage.token, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('hết hạn'), findsOneWidget);
  });
}
