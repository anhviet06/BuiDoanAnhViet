import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/employee_providers.dart';
import '../../services/admin_services.dart';
import '../../services/employee_services.dart';
import 'history_screen.dart';
import 'my_leaves_screen.dart';
import 'profile_screen.dart';
import 'today_screen.dart';

/// Provider có trạng thái của khu vực nhân viên. Đặt TRÊN Navigator (MaterialApp.builder trong app.dart)
/// để các màn được push (form nghỉ phép, đổi mật khẩu...) cũng truy cập được. Tạo lười và gắn key
/// theo userId nên đăng xuất / đổi tài khoản thì tạo lại.
class EmployeeScope extends StatelessWidget {
  final Widget child;

  const EmployeeScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (c) => TodayProvider(c.read<AttendanceService>())..load()),
        ChangeNotifierProvider(create: (c) => HistoryProvider(c.read<AttendanceService>())..load()),
        ChangeNotifierProvider(create: (c) => MyLeavesProvider(c.read<LeaveService>())..load()),
        ChangeNotifierProvider(
            create: (c) => ProfileProvider(c.read<ProfileService>(), c.read<AttendanceService>())..load()),
      ],
      child: child,
    );
  }
}

/// Khung nhân viên: NavigationBar 4 tab (Hôm nay / Lịch sử / Nghỉ phép / Hồ sơ).
class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  int _index = 0;

  static const _titles = ['Hôm nay', 'Lịch sử chấm công', 'Nghỉ phép', 'Hồ sơ'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          // Luôn có cách đăng xuất, kể cả khi tab Hồ sơ không tải được
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [TodayScreen(), HistoryScreen(), MyLeavesScreen(), ProfileScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today_rounded), label: 'Hôm nay'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'Lịch sử'),
          NavigationDestination(icon: Icon(Icons.event_busy_outlined), selectedIcon: Icon(Icons.event_busy_rounded), label: 'Nghỉ phép'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Hồ sơ'),
        ],
      ),
    );
  }
}
