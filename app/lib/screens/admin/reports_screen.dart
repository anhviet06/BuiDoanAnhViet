import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/monthly_report.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/charts.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/month_bar.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_kit.dart';
import 'attendances_admin_screen.dart';
import 'report_detail_screen.dart';

/// Tab Báo cáo: chọn tháng, thẻ tổng, biểu đồ lương / giờ theo nhân viên, danh sách nhân viên.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  /// Mở màn quản lý chấm công rồi tải lại báo cáo (vì admin có thể đã gỡ cờ / đóng ca).
  Future<void> _openAttendances(BuildContext context, {String? status}) async {
    final reports = context.read<ReportsProvider>();
    final m = reports.month;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AttendancesAdminScreen(from: DateTime(m.year, m.month, 1), to: DateTime(m.year, m.month + 1, 0), status: status),
      ),
    );
    reports.load();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ReportsProvider>();
    final r = p.report;
    final labels = _chartLabels([for (final row in r.rows) row.fullName]);
    void openDetail(MonthlySummary row) => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => ReportDetailScreen(userId: row.userId, fullName: row.fullName, month: p.month)),
        );
    return Column(
      children: [
        MonthBar(month: p.month, canGoPrev: !p.loading, canGoNext: p.canGoNext && !p.loading, onPrev: p.previousMonth, onNext: p.nextMonth),
        Expanded(
          child: AsyncBody(
            loading: p.loading,
            error: p.error,
            isEmpty: r.rows.isEmpty,
            onRefresh: p.load,
            emptyView: const EmptyView(
              icon: Icons.bar_chart_outlined,
              title: 'Chưa có nhân viên để báo cáo',
              subtitle: 'Thêm nhân viên ở tab Nhân viên để xem báo cáo tháng.',
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _Totals(report: r),
                if (r.totalSuspicious > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('report_suspicious_banner'),
                    child: SuspiciousBanner(
                      message:
                          '${r.totalSuspicious} lần chấm công nghi ngờ · ${Fmt.money(r.totalSuspiciousPay)} lương đang bị nghi ngờ (vẫn được tính).',
                      actionKey: const Key('report_review_suspicious'),
                      onAction: () => _openAttendances(context, status: 'suspicious'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _ChartCard(
                  title: 'Lương tạm tính theo nhân viên',
                  footnote: r.totalSuspicious > 0 ? 'Cột đỏ: nhân viên có chấm công đang bị nghi ngờ.' : null,
                  child: SimpleBarChart(
                    key: const Key('chart_pay'),
                    bars: [
                      for (final row in r.rows)
                        BarPoint(
                          label: labels[r.rows.indexOf(row)],
                          value: row.netPay,
                          tooltip: '${row.fullName}\n${Fmt.money(row.netPay)}',
                          color: row.suspiciousCount > 0 ? StatusColors.of(context, 'suspicious') : null,
                        ),
                    ],
                    axisFormatter: Fmt.compactMoney,
                    onBarTap: (i) => openDetail(r.rows[i]),
                  ),
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: 'Giờ làm theo nhân viên',
                  child: SimpleBarChart(
                    key: const Key('chart_hours'),
                    bars: [
                      for (final row in r.rows)
                        BarPoint(
                          label: labels[r.rows.indexOf(row)],
                          value: row.totalHours,
                          tooltip: '${row.fullName}\n${Fmt.hours(row.totalHours)}',
                        ),
                    ],
                    axisFormatter: NumberFormatShort.hours,
                    onBarTap: (i) => openDetail(r.rows[i]),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('report_open_attendances'),
                    onPressed: () => _openAttendances(context),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Quản lý chấm công'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Chi tiết theo nhân viên', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final row in r.rows) ...[
                  _EmployeeTile(
                    row: row,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => ReportDetailScreen(userId: row.userId, fullName: row.fullName, month: p.month),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Nhãn trục X = từ cuối họ tên ("Nguyễn Văn An" -> "An"); trùng tên thì thêm chữ cái đầu họ ("N. An").
  static List<String> _chartLabels(List<String> names) {
    String last(String n) {
      final parts = n.trim().split(RegExp(r'\s+'));
      return parts.isEmpty ? '' : parts.last;
    }

    final counts = <String, int>{};
    for (final n in names) {
      counts[last(n)] = (counts[last(n)] ?? 0) + 1;
    }
    return [
      for (final n in names)
        if ((counts[last(n)] ?? 0) > 1 && n.trim().split(RegExp(r'\s+')).length > 1) '${n.trim().characters.first.toUpperCase()}. ${last(n)}' else last(n),
    ];
  }
}

class _Totals extends StatelessWidget {
  final MonthlyReport report;

  const _Totals({required this.report});

  @override
  Widget build(BuildContext context) {
    return MetricGrid(items: [
      MetricItem(
        key: const Key('total_pay'),
        icon: Icons.payments_rounded,
        label: 'Tổng lương (sau phạt)',
        value: Fmt.money(report.totalNetPay),
        highlight: true,
      ),
      MetricItem(key: const Key('total_hours'), icon: Icons.timer_rounded, label: 'Tổng giờ làm', value: Fmt.hours(report.totalHours)),
      MetricItem(
        key: const Key('total_penalty'),
        icon: Icons.gavel_rounded,
        label: 'Tổng tiền phạt',
        value: Fmt.money(report.totalPenalty),
        color: StatusColors.of(context, 'late'),
      ),
      MetricItem(
        key: const Key('total_suspicious'),
        icon: Icons.flag_rounded,
        label: 'Ca nghi ngờ',
        value: '${report.totalSuspicious}',
        color: report.totalSuspicious > 0 ? StatusColors.of(context, 'suspicious') : null,
      ),
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? footnote;

  const _ChartCard({required this.title, required this.child, this.footnote});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
            if (footnote != null) ...[
              const SizedBox(height: 8),
              Text(
                footnote!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final MonthlySummary row;
  final VoidCallback onTap;

  const _EmployeeTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        key: Key('report_row_${row.userId}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.fullName, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${row.daysWorked} ngày công · ${Fmt.hours(row.totalHours)} · phạt ${Fmt.money(row.totalPenalty)}',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    if (row.suspiciousCount > 0 || row.openCount > 0) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (row.suspiciousCount > 0)
                            Pill(
                              label: '${row.suspiciousCount} nghi ngờ',
                              color: StatusColors.of(context, 'suspicious'),
                              icon: Icons.warning_amber_rounded,
                            ),
                          if (row.openCount > 0) Pill(label: '${row.openCount} chưa check-out', color: StatusColors.of(context, 'late')),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Fmt.money(row.netPay),
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
