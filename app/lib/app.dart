import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/employee/employee_home_screen.dart';
import 'screens/splash_screen.dart';

class TimeGuardApp extends StatelessWidget {
  const TimeGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
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
        return AdminScope(
          key: ValueKey(userId),
          child: EmployeeScope(key: ValueKey(userId), child: child!),
        );
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
