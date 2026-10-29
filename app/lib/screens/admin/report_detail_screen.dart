import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/admin_providers.dart';
import '../../services/admin_services.dart';
import '../../widgets/charts.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';
import 'attendances_admin_screen.dart';

/// Chi tiết báo cáo tháng của một nhân viên: số liệu, biểu đồ giờ theo ngày và bảng từng ngày.
class ReportDetailScreen extends StatelessWidget {
  final int userId;
  final String fullName;
  final DateTime month;

  const ReportDetailScreen({super.key, required this.userId, required this.fullName, required this.month});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => UserReportProvider(c.read<ReportService>(), userId: userId, month: month)..load(),
      child: Scaffold(
        appBar: AppBar(title: Text(fullName)),
        body: _Body(userId: userId, fullName: fullName, month: month),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final int userId;
  final String fullName;
  final DateTime month;

  const _Body({required this.userId, required this.fullName, required this.month});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<UserReportProvider>();
    final s = p.summary;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return AsyncBody(
      loading: p.loading,
      error: p.error,
      isEmpty: s == null,
      onRefresh: p.load,
      emptyView: const EmptyView(icon: Icons.bar_chart_outlined, title: 'Không có dữ liệu'),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (s != null) ...[
            Text('Tháng ${month.month}/${month.year}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lương tạm tính', style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(
                      Fmt.money(s.netPay),
                      key: const Key('detail_net_pay'),
                      style: text.headlineMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _Line('Lương theo giờ', Fmt.money(s.hourlyRate)),
                    _Line('Ngày công', '${s.daysWorked}'),
                    _Line('Tổng giờ làm', Fmt.hours(s.totalHours)),
                    _Line('Lương trước phạt', Fmt.money(s.grossPay)),
                    _Line('Tiền phạt', '- ${Fmt.money(s.totalPenalty)}'),
                    _Line('Đi trễ', '${s.lateCount} lần · ${s.totalLateMinutes} phút'),
                    _Line('Ngày nghỉ phép', '${s.leaveDays}'),
                    if (s.suspiciousCount > 0)
                      _Line(
                        'Nghi ngờ',
                        '${s.suspiciousCount} lần · ${Fmt.money(s.suspiciousPay)}',
                        color: StatusColors.of(context, 'suspicious'),
                      ),
                    if (s.openCount > 0)
                      _Line('Chưa check-out', '${s.openCount} ca (chưa tính lương)', color: StatusColors.of(context, 'late')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Giờ làm theo ngày', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    HoursByDayChart(key: const Key('detail_hours_chart'), days: s.days, month: month),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Chi tiết từng ngày', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (s.days.isEmpty)
              const SizedBox(
                height: 120,
                child: EmptyView(icon: Icons.event_note_outlined, title: 'Chưa có chấm công trong tháng này'),
              )
            else
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    key: const Key('detail_table'),
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('Ngày')),
                      DataColumn(label: Text('Giờ'), numeric: true),
                      DataColumn(label: Text('Trễ'), numeric: true),
                      DataColumn(label: Text('Phạt'), numeric: true),
                      DataColumn(label: Text('Lương'), numeric: true),
                      DataColumn(label: Text('Trạng thái')),
                    ],
                    rows: [
                      for (final d in s.days)
                        DataRow(
                          cells: [
                            DataCell(Text('${d.date.day.toString().padLeft(2, '0')}/${d.date.month.toString().padLeft(2, '0')}')),
                            DataCell(Text(Fmt.hours(d.hours))),
                            DataCell(Text(d.lateMinutes > 0 ? '${d.lateMinutes}p' : '-')),
                            DataCell(Text(d.penalty > 0 ? Fmt.money(d.penalty) : '-')),
                            DataCell(Text(Fmt.money(d.pay))),
                            DataCell(Pill(label: StatusColors.label(d.status), color: StatusColors.of(context, d.status))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('detail_open_attendances'),
                onPressed: () async {
                  final reports = context.read<UserReportProvider>();
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => AttendancesAdminScreen(
                        userId: userId,
                        from: DateTime(month.year, month.month, 1),
                        to: DateTime(month.year, month.month + 1, 0),
                      ),
                    ),
                  );
                  reports.load();
                },
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Chấm công của nhân viên này'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Line(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
