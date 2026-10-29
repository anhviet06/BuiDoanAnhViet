import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/monthly_report.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/charts.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/month_bar.dart';
import '../../widgets/shift_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_kit.dart';

/// Tab Lịch sử: chọn tháng (mũi tên trước/sau), thống kê tháng và danh sách theo ngày.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<HistoryProvider>();
    return Column(
      children: [
        MonthBar(
          month: p.month,
          canGoNext: p.canGoNext && !p.loading,
          canGoPrev: !p.loading,
          onPrev: p.previousMonth,
          onNext: p.nextMonth,
        ),
        Expanded(
          child: AsyncBody(
            loading: p.loading,
            error: p.error,
            isEmpty: p.records.isEmpty,
            onRefresh: p.load,
            emptyView: EmptyView(
              icon: Icons.event_note_outlined,
              title: 'Chưa có chấm công trong tháng ${p.month.month}/${p.month.year}',
              subtitle: 'Các lần chấm công của bạn sẽ hiện ở đây.',
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _SummaryCard(summary: p.summary),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Giờ làm theo ngày', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        HoursByDayChart(key: const Key('history_hours_chart'), days: p.summary.days, month: p.month),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final r in p.records) ...[
                  HistoryRecordCard(record: r),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final MonthlySummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricGrid(items: [
          MetricItem(
            key: const Key('history_net_pay'),
            icon: Icons.payments_rounded,
            label: 'Lương tạm tính',
            value: Fmt.money(summary.netPay),
            highlight: true,
          ),
          MetricItem(icon: Icons.work_history_rounded, label: 'Ngày công', value: '${summary.daysWorked}'),
          MetricItem(icon: Icons.timer_rounded, label: 'Tổng giờ', value: Fmt.hours(summary.totalHours)),
          MetricItem(
            icon: Icons.alarm_off_rounded,
            label: 'Đi trễ',
            value: '${summary.lateCount} lần · ${summary.totalLateMinutes} phút',
            color: StatusColors.of(context, 'late'),
          ),
          MetricItem(
            icon: Icons.gavel_rounded,
            label: 'Tiền phạt',
            value: Fmt.money(summary.totalPenalty),
            color: StatusColors.of(context, 'late'),
          ),
          MetricItem(icon: Icons.beach_access_rounded, label: 'Ngày nghỉ phép', value: '${summary.leaveDays}'),
        ]),
        if (summary.suspiciousCount > 0) ...[
          const SizedBox(height: 12),
          MessageBanner(
            message: '${summary.suspiciousCount} lần chấm công bị đánh dấu nghi ngờ, quản trị viên có thể kiểm tra lại.',
            icon: Icons.warning_amber_rounded,
          ),
        ],
        if (summary.openCount > 0) ...[
          const SizedBox(height: 12),
          MessageBanner(
            message: '${summary.openCount} ca chưa check-out nên chưa được tính lương.',
            isError: false,
            icon: Icons.info_outline_rounded,
          ),
        ],
      ],
    );
  }
}
