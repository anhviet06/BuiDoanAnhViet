import '../employee/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_providers.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_services.dart';
import 'leaves_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'shifts_screen.dart';
import 'users_screen.dart';

/// Provider có trạng thái của khu vực admin. Đặt ở TRÊN Navigator (xem MaterialApp.builder trong app.dart)
/// để cả các màn được push (form, chi tiết ca...) đều truy cập được. Tạo lười (chỉ khi admin dùng)
/// và gắn key theo userId nên đăng xuất / đổi tài khoản thì bị hủy và tạo lại, không lộ dữ liệu sang tài khoản khác.
class AdminScope extends StatelessWidget {
  final Widget child;

  const AdminScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (c) => UsersProvider(c.read<UserService>())..load()),
        ChangeNotifierProvider(create: (c) => ShiftsProvider(c.read<ShiftService>())..load()),
        ChangeNotifierProvider(create: (c) => LeavesProvider(c.read<LeaveService>())..load()),
        ChangeNotifierProvider(create: (c) => CompanySettingsProvider(c.read<SettingsService>())..load()),
        ChangeNotifierProvider(create: (c) => ReportsProvider(c.read<ReportService>())..load()),
      ],
      child: child,
    );
  }
}

/// Khung trang quản trị: NavigationBar 4 tab (Nhân viên / Ca làm / Nghỉ phép / Cấu hình).
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const _AdminShell();
}

class _AdminShell extends StatefulWidget {
  const _AdminShell();

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _index = 0;

  static const _titles = ['Nhân viên', 'Ca làm việc', 'Đơn nghỉ phép', 'Cấu hình công ty', 'Báo cáo tháng'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final session = auth.session!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.admin_panel_settings_rounded, size: 18, color: scheme.onPrimaryContainer),
            ),
            onSelected: (v) {
              if (v == 'logout') auth.logout();
              if (v == 'prefs') Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PersonalSettingsScreen()));
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(session.email, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'prefs',
                child: ListTile(leading: Icon(Icons.tune_rounded), title: Text('Cài đặt cá nhân'), contentPadding: EdgeInsets.zero),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Đăng xuất'), contentPadding: EdgeInsets.zero),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [UsersScreen(), ShiftsScreen(), LeavesScreen(), SettingsScreen(), ReportsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Nhân viên'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule_rounded), label: 'Ca làm'),
          NavigationDestination(icon: Icon(Icons.event_busy_outlined), selectedIcon: Icon(Icons.event_busy_rounded), label: 'Nghỉ phép'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Cấu hình'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Báo cáo'),
        ],
      ),
    );
  }
}
