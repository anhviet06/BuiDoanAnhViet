import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/attendance.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/shift_card.dart';
import '../../widgets/state_views.dart';
import 'check_flow_screen.dart';

/// Tab Hôm nay: lời chào, ngày, ca làm hôm nay + trạng thái chấm công, nút Chấm công.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  /// Mở luồng chấm công (vân tay -> GPS -> QR). Xong thì tải lại các tab liên quan.
  Future<void> _startCheck(BuildContext context, {int? shiftId}) async {
    final today = context.read<TodayProvider>();
    if (today.info == null) {
      showAppSnack(context, 'Chưa tải được dữ liệu hôm nay. Hãy kéo để làm mới rồi thử lại.', error: true);
      today.load();
      return;
    }
    final history = context.read<HistoryProvider>();
    final profile = context.read<ProfileProvider>();
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CheckFlowScreen(shiftId: shiftId)));
    // Dù thành công hay không cũng làm mới: trạng thái trên server có thể đã đổi
    today.load();
    history.load();
    profile.load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TodayProvider>();
    final name = context.watch<AuthProvider>().session?.fullName ?? '';
    final info = p.info;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('checkin_button'),
        heroTag: null,
        onPressed: () => _startCheck(context),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 26),
        label: const Text('Chấm công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      body: AsyncBody(
        loading: p.loading,
        error: p.error,
        isEmpty: info == null,
        onRefresh: p.load,
        emptyView: const EmptyView(icon: Icons.today_outlined, title: 'Chưa có dữ liệu hôm nay'),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            if (info != null) ...[
              _Header(name: name, date: info.date, items: info.items),
              const SizedBox(height: 16),
              if (info.onLeave) ...[
                const MessageBanner(
                  message: 'Hôm nay bạn có đơn nghỉ phép đã được duyệt, không cần chấm công.',
                  isError: false,
                  icon: Icons.beach_access_rounded,
                ),
                const SizedBox(height: 16),
              ],
              if (info.items.isEmpty)
                const SizedBox(
                  height: 220,
                  child: EmptyView(
                    icon: Icons.schedule_outlined,
                    title: 'Hôm nay chưa có ca làm việc',
                    subtitle: 'Khi quản trị viên tạo ca, ca sẽ hiện ở đây.',
                  ),
                )
              else
                for (final item in info.items) ...[
                  TodayShiftCard(
                    shift: item.shift,
                    attendance: item.attendance,
                    onCheckOut: () => _startCheck(context, shiftId: item.shift.id),
                    blockedByShift: (info.openInHours != null && info.openInHours!.shift.id != item.shift.id) ? info.openInHours!.shift.name : null,
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final DateTime date;
  final List<TodayItem> items;

  const _Header({required this.name, required this.date, required this.items});

  /// Dòng trạng thái lấy từ dữ liệu ca hôm nay đã có (không gọi API mới).
  String _statusLine(DateTime now) {
    final open = items.where((i) => i.attendance != null && i.attendance!.isOpen).toList();
    if (open.isNotEmpty) {
      final since = now.difference(open.first.attendance!.checkInAt.toLocal());
      final mins = since.inMinutes < 0 ? 0 : since.inMinutes;
      return 'Đang làm: ${mins ~/ 60} giờ ${mins % 60} phút';
    }
    if (items.isNotEmpty && items.every((i) => i.attendance != null)) return 'Đã hoàn thành hôm nay';
    return 'Hôm nay bạn chưa chấm công';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const onHero = Colors.white;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.brandDeep, AppColors.brandMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
            ),
            Positioned(
              right: 30,
              bottom: -50,
              child: Container(width: 110, height: 110, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06))),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xin chào,', style: text.bodyMedium?.copyWith(color: onHero.withValues(alpha: 0.85))),
                  const SizedBox(height: 2),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.headlineSmall?.copyWith(color: onHero, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: onHero.withValues(alpha: 0.9)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(Fmt.weekdayDate(date), maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium?.copyWith(color: onHero))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LiveClock(builder: (now) {
                    final hh = now.hour.toString().padLeft(2, '0');
                    final mm = now.minute.toString().padLeft(2, '0');
                    final ss = now.second.toString().padLeft(2, '0');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$hh:$mm:$ss',
                            key: const Key('today_clock'),
                            style: const TextStyle(color: onHero, fontSize: 34, fontWeight: FontWeight.w700, fontFeatures: AppTypography.tabular, height: 1.1)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                          child: Text(_statusLine(now), key: const Key('today_status_line'), style: const TextStyle(color: onHero, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Đồng hồ giờ máy chạy theo giây. Timer được hủy khi widget bị gỡ.
class _LiveClock extends StatefulWidget {
  final Widget Function(DateTime now) builder;

  const _LiveClock({required this.builder});

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_now);
}
