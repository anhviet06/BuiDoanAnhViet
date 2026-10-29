import 'package:buidoananhviet/screens/admin/admin_home_screen.dart';
import 'package:buidoananhviet/screens/auth/login_screen.dart';
import 'package:buidoananhviet/screens/auth/otp_screen.dart';
import 'package:buidoananhviet/screens/auth/register_screen.dart';
import 'package:buidoananhviet/screens/employee/employee_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _goodPassword = 'MatKhauTest@1';

/// Backend giả cho luồng auth: OTP lần đầu là 123456, gửi lại thì 654321.
FakeBackend fakeAuthBackend() {
  var otp = '123456';
  var loginCalls = 0;
  return FakeBackend((o) {
    final body = (o.data ?? {}) as Map;
    switch (o.path) {
      case '/api/Authenticate/login':
        if (body['password'] != _goodPassword) {
          return (status: 401, body: {'success': false, 'message': 'Sai tên đăng nhập hoặc mật khẩu'});
        }
        loginCalls++;
        otp = loginCalls == 1 ? '123456' : '654321';
        return (status: 200, body: {'success': true, 'message': 'Đã gửi mã OTP tới email', 'otpRequired': true, 'devOtp': otp});
      case '/api/Authenticate/verify-otp':
        if (body['otp'] != otp) return (status: 401, body: {'success': false, 'message': 'OTP không đúng'});
        final isAdmin = body['username'] == 'admin';
        return (
          status: 200,
          body: {
            'success': true,
            'token': makeJwt(role: isAdmin ? 'admin' : 'employee', name: body['username'] as String),
            'role': isAdmin ? 'admin' : 'employee',
            'user': {'fullName': isAdmin ? 'Quản trị viên' : 'Nguyễn Văn An'},
          }
        );
      case '/api/Authenticate/register':
        if (body['email'] == 'dup@x.com') {
          return (status: 400, body: {'success': false, 'message': 'Email hoặc tên đăng nhập đã tồn tại'});
        }
        otp = '123456';
        return (
          status: 200,
          body: {
            'success': true,
            'message': 'Tạo tài khoản thành công, đã gửi mã OTP tới email',
            'otpRequired': true,
            'otpSent': true,
            if (!(body['email'] as String).startsWith('real')) 'devOtp': otp,
          }
        );
    }
    return (status: 404, body: {});
  });
}

Finder field(String key) => find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText));

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<FakeBackend> openApp(WidgetTester tester, {FakeTokenStorage? storage}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  final backend = fakeAuthBackend();
  final t = buildTestApp(storage ?? FakeTokenStorage(), backend);
  await t.auth.init();
  await tester.pumpWidget(t.app);
  return backend;
}

Future<void> doLogin(WidgetTester tester, String id, [String pw = _goodPassword]) async {
  await tester.enterText(field('login_id'), id);
  await tester.enterText(field('login_password'), pw);
  await tester.tap(find.byKey(const Key('login_submit')));
  await settle(tester);
}

void main() {
  group('Đăng nhập', () {
    testWidgets('để trống -> báo lỗi, không gọi API', (tester) async {
      final backend = await openApp(tester);
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pump();
      expect(find.text('Email hoặc tên đăng nhập không được để trống'), findsOneWidget);
      expect(find.text('Mật khẩu không được để trống'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('sai mật khẩu -> hiện message của server, ở lại màn đăng nhập', (tester) async {
      await openApp(tester);
      await doLogin(tester, 'annguyen', 'sai');
      expect(find.text('Sai tên đăng nhập hoặc mật khẩu'), findsOneWidget);
      expect(find.byType(OtpScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('đúng -> sang màn OTP có banner demo', (tester) async {
      final backend = await openApp(tester);
      await doLogin(tester, 'annguyen');
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(find.text('Chế độ demo: OTP là 123456'), findsOneWidget);
      // gửi đúng 1 ô định danh (email hoặc username) lên server
      expect(backend.to('/api/Authenticate/login').single.data['username'], 'annguyen');
    });

    testWidgets('quay lại từ màn OTP về đăng nhập', (tester) async {
      await openApp(tester);
      await doLogin(tester, 'annguyen');
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('OTP', () {
    testWidgets('Tự điền + Xác nhận -> dashboard nhân viên, màn đăng nhập/OTP đã đóng', (tester) async {
      final storage = FakeTokenStorage();
      await openApp(tester, storage: storage);
      await doLogin(tester, 'annguyen');
      await tester.tap(find.byKey(const Key('otp_fill')));
      await tester.pump();
      expect(tester.widget<EditableText>(field('otp_field')).controller.text, '123456');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await settle(tester);
      expect(find.byType(EmployeeHomeScreen), findsOneWidget);
      expect(find.byType(OtpScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(storage.token, isNotNull);
    });

    testWidgets('tài khoản admin -> trang quản trị', (tester) async {
      await openApp(tester);
      await doLogin(tester, 'admin');
      await tester.tap(find.byKey(const Key('otp_fill')));
      await tester.tap(find.byKey(const Key('otp_submit')));
      await settle(tester);
      expect(find.byType(AdminHomeScreen), findsOneWidget);
      expect(find.byType(OtpScreen), findsNothing);
    });

    testWidgets('OTP sai -> báo lỗi, vẫn ở màn OTP, xóa ô nhập', (tester) async {
      await openApp(tester);
      await doLogin(tester, 'annguyen');
      await tester.enterText(field('otp_field'), '000000');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await settle(tester);
      expect(find.text('OTP không đúng'), findsOneWidget);
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(tester.widget<EditableText>(field('otp_field')).controller.text, '');
    });

    testWidgets('OTP thiếu số -> validate, không gọi API', (tester) async {
      final backend = await openApp(tester);
      await doLogin(tester, 'annguyen');
      await tester.enterText(field('otp_field'), '123');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await tester.pump();
      expect(find.text('Mã OTP gồm 6 chữ số'), findsOneWidget);
      expect(backend.to('/api/Authenticate/verify-otp'), isEmpty);
    });

    testWidgets('chỉ nhận chữ số', (tester) async {
      await openApp(tester);
      await doLogin(tester, 'annguyen');
      await tester.enterText(field('otp_field'), '12ab34');
      expect(tester.widget<EditableText>(field('otp_field')).controller.text, '1234');
    });

    testWidgets('gửi lại: khóa 30 giây rồi gọi lại bước 1, banner cập nhật OTP mới', (tester) async {
      final backend = await openApp(tester);
      await doLogin(tester, 'annguyen');
      // Vừa vào màn OTP (đã trôi ~1.5s trong lúc chờ API): đang đếm ngược, nút bị khóa
      expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const Key('otp_resend'))).onPressed, isNull);

      int secondsLeft() => int.parse(RegExp(r'(\d+)s').firstMatch(tester.widget<Text>(find.descendant(of: find.byKey(const Key('otp_resend')), matching: find.byType(Text))).data!)!.group(1)!);
      final before = secondsLeft();
      await tester.pump(const Duration(seconds: 10));
      expect(secondsLeft(), before - 10);

      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Gửi lại mã'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const Key('otp_resend'))).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('otp_resend')));
      await settle(tester);
      expect(backend.to('/api/Authenticate/login').length, 2);
      expect(find.text('Chế độ demo: OTP là 654321'), findsOneWidget);
      expect(find.text('Đã gửi lại mã OTP.'), findsOneWidget);
      expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);
      expect(tester.widget<TextButton>(find.byKey(const Key('otp_resend'))).onPressed, isNull);

      // OTP mới dùng được, OTP cũ thì không
      await tester.enterText(field('otp_field'), '123456');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await settle(tester);
      expect(find.text('OTP không đúng'), findsOneWidget);
      await tester.tap(find.byKey(const Key('otp_fill')));
      await tester.tap(find.byKey(const Key('otp_submit')));
      await settle(tester);
      expect(find.byType(EmployeeHomeScreen), findsOneWidget);
    });
  });

  group('Đăng ký', () {
    Future<void> fillRegister(WidgetTester tester, {String email = 'new@x.com', String confirm = 'abc123'}) async {
      await tester.enterText(field('reg_name'), 'Người Mới');
      await tester.enterText(field('reg_email'), email);
      await tester.enterText(field('reg_password'), 'abc123');
      await tester.enterText(field('reg_confirm'), confirm);
      await tester.tap(find.byKey(const Key('reg_submit')));
      await settle(tester);
    }

    testWidgets('validate: email sai, mật khẩu ngắn, nhập lại không khớp', (tester) async {
      final backend = await openApp(tester);
      await tester.tap(find.byKey(const Key('login_to_register')));
      await settle(tester);
      await tester.enterText(field('reg_name'), 'A');
      await tester.enterText(field('reg_email'), 'khong-phai-email');
      await tester.enterText(field('reg_password'), '123');
      await tester.enterText(field('reg_confirm'), '456');
      await tester.tap(find.byKey(const Key('reg_submit')));
      await tester.pump();
      expect(find.text('Email không hợp lệ'), findsOneWidget);
      expect(find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);
      expect(find.text('Mật khẩu nhập lại không khớp'), findsOneWidget);
      expect(backend.to('/api/Authenticate/register'), isEmpty);
    });

    testWidgets('thành công -> sang màn OTP (có banner demo), nhập OTP xong mới vào app', (tester) async {
      final storage = FakeTokenStorage();
      final backend = await openApp(tester, storage: storage);
      await tester.tap(find.byKey(const Key('login_to_register')));
      await settle(tester);
      expect(find.byType(RegisterScreen), findsOneWidget);
      await fillRegister(tester);
      // màn đăng ký được thay bằng màn OTP; chưa có token
      expect(find.byType(RegisterScreen), findsNothing);
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(storage.token, isNull);
      expect(find.text('Chế độ demo: OTP là 123456'), findsOneWidget);
      final sent = backend.to('/api/Authenticate/register').single.data as Map;
      expect(sent['email'], 'new@x.com');
      expect(sent['fullName'], 'Người Mới');
      expect(sent.containsKey('username'), false, reason: 'bỏ trống username thì không gửi (server lấy phần trước @)');

      await tester.tap(find.byKey(const Key('otp_fill')));
      await tester.tap(find.byKey(const Key('otp_submit')));
      await settle(tester);
      expect(storage.token, isNotNull);
      expect(find.byType(EmployeeHomeScreen), findsOneWidget);
      expect(find.byType(OtpScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      // OTP được xác thực theo email vừa đăng ký
      expect(backend.to('/api/Authenticate/verify-otp').single.data['username'], 'new@x.com');
    });

    testWidgets('có nhập tên đăng nhập -> gửi lên server; OTP sai thì ở lại màn OTP', (tester) async {
      final backend = await openApp(tester);
      await tester.tap(find.byKey(const Key('login_to_register')));
      await settle(tester);
      await tester.enterText(field('reg_username'), 'nguoimoi');
      await fillRegister(tester);
      expect((backend.to('/api/Authenticate/register').single.data as Map)['username'], 'nguoimoi');
      await tester.enterText(field('otp_field'), '000000');
      await tester.tap(find.byKey(const Key('otp_submit')));
      await settle(tester);
      expect(find.text('OTP không đúng'), findsOneWidget);
      expect(find.byType(OtpScreen), findsOneWidget);
    });

    testWidgets('server không bật DevMode (OTP gửi qua email): không có banner demo, vẫn nhập OTP được; Gửi lại mã gọi bước 1', (tester) async {
      final backend = await openApp(tester);
      await tester.tap(find.byKey(const Key('login_to_register')));
      await settle(tester);
      await fillRegister(tester, email: 'real@x.com');
      expect(find.byType(OtpScreen), findsOneWidget);
      expect(find.byKey(const Key('otp_dev_banner')), findsNothing);
      // sau 30 giây bấm "Gửi lại mã" -> gọi lại login với email + mật khẩu vừa đăng ký
      await tester.pump(const Duration(seconds: 31));
      await tester.tap(find.byKey(const Key('otp_resend')));
      await settle(tester);
      final login = backend.to('/api/Authenticate/login').single.data as Map;
      expect(login['username'], 'real@x.com');
      expect(login['password'], 'abc123');
    });

    testWidgets('email đã tồn tại -> hiện lỗi server, ở lại màn đăng ký', (tester) async {
      await openApp(tester);
      await tester.tap(find.byKey(const Key('login_to_register')));
      await settle(tester);
      await fillRegister(tester, email: 'dup@x.com');
      expect(find.text('Email hoặc tên đăng nhập đã tồn tại'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });
}
