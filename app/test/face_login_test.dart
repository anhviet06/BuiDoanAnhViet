import 'dart:convert';

import 'package:buidoananhviet/providers/auth_provider.dart';
import 'package:buidoananhviet/providers/face_login_provider.dart';
import 'package:buidoananhviet/screens/auth/face_login_screens.dart';
import 'package:buidoananhviet/screens/auth/login_screen.dart';
import 'package:buidoananhviet/screens/employee/employee_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fake_employee_backend.dart';
import 'helpers.dart';

Finder field(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText));

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _name = 'Nguyễn Văn An';
String _profileJson({String token = 'tok-saved', int userId = 2}) => jsonEncode({'userId': userId, 'fullName': _name, 'deviceToken': token});

class Env {
  final FakeEmployeeBackend fake;
  final FakeTokenStorage storage;
  final AuthProvider auth;
  int deviceLoginStatus = 200;

  Env(this.fake, this.storage, this.auth);

  List<dynamic> reqs(String path, [String? method]) => fake.adapter.requests.where((r) => r.path == path && (method == null || r.method == method)).toList();
}

Future<Env> open(WidgetTester tester, {bool loggedIn = false, bool faceEnabled = false, String? promptCount}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final fake = FakeEmployeeBackend();
  final storage = FakeTokenStorage(token: loggedIn ? makeJwt() : null, fullName: loggedIn ? _name : null);
  if (faceEnabled) storage.values[FaceLoginProvider.profileKey] = _profileJson();
  if (promptCount != null) storage.values[FaceLoginProvider.promptCountKey] = promptCount;
  final t = buildTestApp(storage, fake.adapter);
  final env = Env(fake, storage, t.auth);

  fake.adapter.interceptor = (o) {
    switch (o.path) {
      case '/api/Authenticate/login':
        return (status: 200, body: {'success': true, 'message': 'Đã gửi mã OTP tới email', 'otpRequired': true, 'devOtp': '123456'});
      case '/api/Authenticate/verify-otp':
        return (status: 200, body: {'success': true, 'token': makeJwt(), 'role': 'employee', 'user': {'fullName': _name}});
      case '/api/Authenticate/device-token':
        if (o.method == 'POST') return (status: 200, body: {'success': true, 'deviceToken': 'dev-token-1'});
        return (status: 204, body: null);
      case '/api/Authenticate/device-login':
        if (env.deviceLoginStatus == 401) {
          return (status: 401, body: {'success': false, 'message': 'Không đăng nhập được bằng khuôn mặt. Hãy đăng nhập bằng mật khẩu và OTP.'});
        }
        return (status: 200, body: {'success': true, 'token': makeJwt(), 'role': 'employee', 'user': {'fullName': _name}});
    }
    return null;
  };

  await t.auth.init();
  await tester.pumpWidget(t.app);
  await settle(tester);
  return env;
}

/// Đăng nhập bằng mật khẩu + OTP demo.
Future<void> passwordLogin(WidgetTester tester) async {
  await tester.enterText(field('login_id'), 'annguyen');
  await tester.enterText(field('login_password'), 'matkhau1');
  await tester.tap(find.byKey(const Key('login_submit')));
  await settle(tester);
  await tester.tap(find.byKey(const Key('otp_fill')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('otp_submit')));
  await settle(tester);
}

const _promptTitle = 'Bật đăng nhập bằng khuôn mặt cho lần sau?';

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('Sau lần đăng nhập mật khẩu + OTP đầu tiên', () {
    testWidgets('hiện hộp hỏi; chọn Bật -> liveness -> xin token thiết bị và lưu trên máy', (tester) async {
      final env = await open(tester);
      await passwordLogin(tester);
      expect(find.byType(EmployeeHomeScreen), findsOneWidget);
      expect(find.text(_promptTitle), findsOneWidget);

      await tester.tap(find.byKey(const Key('face_prompt_enable')));
      await settle(tester);
      expect(find.byType(FaceEnableScreen), findsOneWidget);
      expect(find.text('Bỏ qua (chỉ để demo)'), findsNothing, reason: 'không có nút Bỏ qua ở luồng này');
      await tester.tap(find.byKey(const Key('fake_face_ok')));
      await settle(tester);

      final post = env.reqs('/api/Authenticate/device-token', 'POST').single;
      expect((post.data as Map)['deviceId'], isNotEmpty);
      expect(env.storage.values[FaceLoginProvider.profileKey], contains('dev-token-1'));
      expect(find.byType(FaceEnableScreen), findsNothing);
      expect(find.byType(EmployeeHomeScreen), findsOneWidget);
    });

    testWidgets('chọn Để sau: hỏi lại ở lần đăng nhập mật khẩu kế tiếp, tối đa 2 lần', (tester) async {
      final env = await open(tester);
      await passwordLogin(tester);
      expect(find.text(_promptTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('face_prompt_later')));
      await settle(tester);
      expect(env.storage.values[FaceLoginProvider.promptCountKey], '1');
      expect(env.reqs('/api/Authenticate/device-token'), isEmpty);

      await env.auth.logout();
      await settle(tester);
      await passwordLogin(tester);
      expect(find.text(_promptTitle), findsOneWidget, reason: 'lần 2');
      await tester.tap(find.byKey(const Key('face_prompt_later')));
      await settle(tester);
      expect(env.storage.values[FaceLoginProvider.promptCountKey], '2');

      await env.auth.logout();
      await settle(tester);
      await passwordLogin(tester);
      expect(find.text(_promptTitle), findsNothing, reason: 'đã hỏi đủ 2 lần');
      expect(find.byType(EmployeeHomeScreen), findsOneWidget);
    });

    testWidgets('máy đã bật thì không hỏi nữa', (tester) async {
      await open(tester, faceEnabled: true);
      await tester.tap(find.byKey(const Key('login_use_password')));
      await settle(tester);
      await passwordLogin(tester);
      expect(find.text(_promptTitle), findsNothing);
    });
  });

  group('Đăng nhập bằng khuôn mặt (máy đã bật)', () {
    testWidgets('màn đăng nhập hiện "Chào lại, <Họ tên>" + nút khuôn mặt; quét xong vào thẳng app, không qua OTP', (tester) async {
      final env = await open(tester, faceEnabled: true);
      expect(find.text('Chào lại, $_name'), findsOneWidget);
      expect(find.byKey(const Key('login_face')), findsOneWidget);
      expect(find.byKey(const Key('login_use_password')), findsOneWidget);
      expect(find.text('Không phải bạn? Đổi tài khoản'), findsOneWidget);

      await tester.tap(find.byKey(const Key('login_face')));
      await settle(tester);
      expect(find.byType(FaceLoginScreen), findsOneWidget);
      expect(find.text('Bỏ qua (chỉ để demo)'), findsNothing);
      await tester.tap(find.byKey(const Key('fake_face_ok')));
      await settle(tester);

      final body = env.reqs('/api/Authenticate/device-login').single.data as Map;
      expect(body['deviceToken'], 'tok-saved');
      expect(body['faceVerified'], true);
      expect(body['deviceId'], isNotEmpty);
      expect(find.byType(EmployeeHomeScreen), findsOneWidget);
      expect(env.reqs('/api/Authenticate/login'), isEmpty, reason: 'không hỏi mật khẩu/OTP');
      expect(env.storage.token, isNotNull);
    });

    testWidgets('đăng xuất thường GIỮ hồ sơ: lần sau lại thấy "Chào lại"', (tester) async {
      final env = await open(tester, loggedIn: true, faceEnabled: true);
      expect(find.byType(EmployeeHomeScreen), findsOneWidget);
      await env.auth.logout();
      await settle(tester);
      expect(env.storage.values[FaceLoginProvider.profileKey], isNotNull);
      expect(find.text('Chào lại, $_name'), findsOneWidget);
      expect(env.reqs('/api/Authenticate/device-token', 'DELETE'), isEmpty);
    });

    testWidgets('server từ chối (401): xóa hồ sơ cục bộ, về mật khẩu + OTP kèm thông báo rõ', (tester) async {
      final env = await open(tester, faceEnabled: true);
      env.deviceLoginStatus = 401;
      await tester.tap(find.byKey(const Key('login_face')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('fake_face_ok')));
      await settle(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(FaceLoginProvider.expiredMessage), findsOneWidget);
      expect(find.byKey(const Key('login_id')), findsOneWidget, reason: 'hiện form mật khẩu');
      expect(find.byKey(const Key('login_face')), findsNothing);
      expect(env.storage.values.containsKey(FaceLoginProvider.profileKey), false);
    });

    testWidgets('liveness thất bại 3 lần: về mật khẩu + OTP kèm thông báo, hồ sơ vẫn giữ', (tester) async {
      final env = await open(tester, faceEnabled: true);
      await tester.tap(find.byKey(const Key('login_face')));
      await settle(tester);
      expect(find.text('Lần thử 1/3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fake_face_fail')));
      await settle(tester);
      expect(find.text('Lần thử 2/3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fake_face_fail')));
      await settle(tester);
      expect(find.text('Lần thử 3/3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fake_face_fail')));
      await settle(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Xác thực khuôn mặt thất bại 3 lần. Hãy đăng nhập bằng mật khẩu và OTP.'), findsOneWidget);
      expect(find.byKey(const Key('login_id')), findsOneWidget);
      expect(env.storage.values.containsKey(FaceLoginProvider.profileKey), true);
      expect(env.reqs('/api/Authenticate/device-login'), isEmpty, reason: 'chưa qua liveness thì không gọi server');
    });

    testWidgets('"Dùng mật khẩu" hiện form đăng nhập thường', (tester) async {
      await open(tester, faceEnabled: true);
      await tester.tap(find.byKey(const Key('login_use_password')));
      await settle(tester);
      expect(find.byKey(const Key('login_id')), findsOneWidget);
      expect(find.byKey(const Key('login_face')), findsNothing);
    });

    testWidgets('"Không phải bạn? Đổi tài khoản": xác nhận -> thu hồi trên server, xóa hồ sơ, về form', (tester) async {
      final env = await open(tester, faceEnabled: true);
      await tester.tap(find.byKey(const Key('login_switch_account')));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Đổi tài khoản'));
      await settle(tester);

      final del = env.reqs('/api/Authenticate/device-token', 'DELETE').single;
      expect((del.data as Map)['deviceToken'], 'tok-saved');
      expect(env.storage.values.containsKey(FaceLoginProvider.profileKey), false);
      expect(find.byKey(const Key('login_id')), findsOneWidget);
    });
  });

  group('Công tắc trong Cài đặt', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Hồ sơ')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('profile_settings')));
      await tester.tap(find.byKey(const Key('profile_settings')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('settings_face_switch')));
    }

    testWidgets('bật rồi tắt: gọi đúng API và cập nhật công tắc', (tester) async {
      final env = await open(tester, loggedIn: true, promptCount: '2');
      await openSettings(tester);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('settings_face_switch'))).value, false);

      await tester.tap(find.byKey(const Key('settings_face_switch')));
      await settle(tester);
      expect(find.byType(FaceEnableScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('fake_face_ok')));
      await settle(tester);
      expect(env.reqs('/api/Authenticate/device-token', 'POST'), hasLength(1));
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('settings_face_switch'))).value, true);

      await tester.tap(find.byKey(const Key('settings_face_switch')));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Tắt'));
      await settle(tester);
      expect(env.reqs('/api/Authenticate/device-token', 'DELETE'), hasLength(1));
      expect(env.storage.values.containsKey(FaceLoginProvider.profileKey), false);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('settings_face_switch'))).value, false);
    });
  });

  group('FaceLoginProfile', () {
    test('đọc/ghi JSON; dữ liệu hỏng hoặc thiếu token thì null', () {
      final p = FaceLoginProfile.tryParse(_profileJson(token: 'abc'))!;
      expect((p.userId, p.fullName, p.deviceToken), (2, _name, 'abc'));
      expect(FaceLoginProfile.tryParse(null), isNull);
      expect(FaceLoginProfile.tryParse('khong-phai-json'), isNull);
      expect(FaceLoginProfile.tryParse('{"userId":2,"fullName":"A","deviceToken":""}'), isNull);
    });
  });
}
