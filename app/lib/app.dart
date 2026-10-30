import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/face_login_provider.dart';
import 'screens/auth/face_login_screens.dart';
import 'providers/settings_provider.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/employee/employee_home_screen.dart';
import 'screens/splash_screen.dart';

class TimeGuardApp extends StatelessWidget {
  const TimeGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cài đặt cá nhân (màu chủ đạo, nền, chế độ sáng/tối, cỡ chữ); mặc định = giao diện gốc
    final prefs = context.watch<SettingsProvider>().prefs;
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light, accent: prefs.accent, background: prefs.background),
      darkTheme: AppTheme.build(Brightness.dark, accent: prefs.accent, background: prefs.background),
      themeMode: prefs.themeMode,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Provider admin nằm trên Navigator; key theo userId để đăng xuất/đổi tài khoản thì tạo lại
      builder: (context, child) {
        final userId = context.select<AuthProvider, int?>((a) => a.session?.userId);
        Widget content = AdminScope(
          key: ValueKey(userId),
          child: EmployeeScope(key: ValueKey(userId), child: child!),
        );
        // Cỡ chữ người dùng chọn nhân với cỡ chữ hệ thống (1.0 thì không can thiệp)
        if (prefs.fontScale != 1.0) {
          final mq = MediaQuery.of(context);
          content = MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * prefs.fontScale)),
            child: content,
          );
        }
        return content;
      },
      home: const AuthGate(),
    );
  }
}

/// Điều hướng theo trạng thái đăng nhập và role: chưa đăng nhập -> đăng nhập,
/// admin -> trang quản trị, employee -> dashboard nhân viên.
/// Khi trạng thái đổi (đăng nhập xong / đăng xuất / hết phiên) sẽ đóng mọi màn con đang mở
/// (vd: màn OTP) để màn gốc mới hiện ra.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthStatus? _last;

  Future<void> _askEnableFace() async {
    if (!mounted) return;
    final face = context.read<FaceLoginProvider>();
    if (!await face.shouldPrompt() || !mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bật đăng nhập bằng khuôn mặt cho lần sau?'),
        content: const Text('Lần sau bạn chỉ cần quét khuôn mặt, không phải nhập lại mật khẩu và OTP. Bạn vẫn có thể tắt trong Cài đặt.'),
        actions: [
          TextButton(key: const Key('face_prompt_later'), onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
          FilledButton(
            key: const Key('face_prompt_enable'),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bật'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (enable == true) {
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const FaceEnableScreen()));
    } else {
      await face.postponePrompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final status = auth.status;
    if (_last != null && _last != status) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _last = status;

    // Vừa đăng nhập bằng mật khẩu + OTP: hỏi có bật đăng nhập bằng khuôn mặt cho lần sau không
    if (status == AuthStatus.authenticated && auth.pendingFacePrompt) {
      auth.consumeFacePrompt();
      WidgetsBinding.instance.addPostFrameCallback((_) => _askEnableFace());
    }

    switch (status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return auth.session!.isAdmin ? const AdminHomeScreen() : const EmployeeHomeScreen();
    }
  }
}
