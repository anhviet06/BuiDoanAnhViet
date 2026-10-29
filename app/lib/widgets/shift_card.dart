import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/attendance.dart';
import '../models/shift.dart';
import 'common_widgets.dart';

/// Thẻ ca làm (phần HIỂN THỊ THUẦN: chỉ nhận chuỗi/giá trị). Dùng ở Hôm nay, Lịch sử, Quản lý chấm công.
/// Thanh màu mảnh bên trái theo trạng thái: xanh = đúng giờ, cam = trễ, đỏ = nghi ngờ, xám = chưa chấm.
class ShiftCardView extends StatelessWidget {
  final String title;
  final String? subtitle; // giờ ca / ân hạn
  final String status; // on-time | late | suspicious | none
  final String statusLabel;
  final Widget? leading; // ví dụ khối ngày ở Lịch sử
  final String? checkIn; // "08:03"
  final String? checkOut; // null = chưa ra ca
  final String? hours;
  final bool showTimes;
  final bool isOpen; // đang làm: cột Ra "--:--" + chấm xanh nhấp nháy
  final String? openCaption;
  final String? lateLine;
  final String? suspiciousLine;
  final String? payLine;
  final Widget? footer;
  final String? blockedNote; // có = ca bị khóa (đang trong ca khác chưa check-out): thẻ mờ + dòng ghi chú

  const ShiftCardView({
    super.key,
    required this.title,
    required this.status,
    required this.statusLabel,
    this.subtitle,
    this.leading,
    this.checkIn,
    this.checkOut,
    this.hours,
    this.showTimes = false,
    this.isOpen = false,
    this.openCaption,
    this.lateLine,
    this.suspiciousLine,
    this.payLine,
    this.footer,
    this.blockedNote,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final barColor = status == 'none' ? scheme.outlineVariant : StatusColors.of(context, status);
    final pillColor = status == 'none' ? scheme.outline : StatusColors.of(context, status);

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: barColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (leading != null) ...[leading!, const SizedBox(width: 12)],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: AppTypography.subtitle(context))],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Pill(label: statusLabel, color: pillColor),
                        ),
                      ],
                    ),
                    if (blockedNote != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        Icon(Icons.lock_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(child: Text(blockedNote!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant))),
                      ]),
                    ],
                    if (showTimes) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _TimeCol(label: 'Vào', value: checkIn ?? '--:--'),
                            ),
                            Expanded(
                              child: _TimeCol(label: 'Ra', value: checkOut ?? '--:--', live: isOpen),
                            ),
                            Expanded(
                              child: _TimeCol(label: 'Số giờ', value: hours ?? '--'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (openCaption != null) ...[const SizedBox(height: 8), Text(openCaption!, style: AppTypography.subtitle(context))],
                    if (lateLine != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        lateLine!,
                        style: TextStyle(color: StatusColors.textOf(context, 'late'), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                    if (suspiciousLine != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: StatusColors.of(context, 'suspicious').withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: StatusColors.of(context, 'suspicious').withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.flag_rounded, size: 16, color: StatusColors.of(context, 'suspicious')),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                suspiciousLine!,
                                style: TextStyle(fontSize: 13, color: StatusColors.textOf(context, 'suspicious')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (payLine != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        payLine!,
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: AppTypography.tabular),
                      ),
                    ],
                    if (footer != null) ...[const SizedBox(height: 8), footer!],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return blockedNote == null ? card : Opacity(opacity: 0.55, child: card);
  }
}

class _TimeCol extends StatelessWidget {
  final String label;
  final String value;
  final bool live;

  const _TimeCol({required this.label, required this.value, this.live = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (live) ...[const _LiveDot(), const SizedBox(width: 5)],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, maxLines: 1, style: AppTypography.metric(context, size: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Chấm xanh nhấp nháy vài nhịp (hữu hạn để không giữ khung hình chạy mãi).
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true, count: 8);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = StatusColors.of(context, 'on-time');
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Thẻ ca ở tab Hôm nay: nhận TodayItem (shift + attendance?) và dựng [ShiftCardView].
class TodayShiftCard extends StatelessWidget {
  final Shift shift;
  final Attendance? attendance;
  final String? blockedByShift; // tên ca đang mở còn trong giờ (khóa ca này)
  final VoidCallback? onCheckOut; // có thì ca đang mở hiện nút "Check-out ca này"

  const TodayShiftCard({super.key, required this.shift, required this.attendance, this.blockedByShift, this.onCheckOut});

  @override
  Widget build(BuildContext context) {
    final a = attendance;
    if (a == null) {
      return ShiftCardView(
        title: shift.name,
        subtitle: 'Giờ ca ${shift.rangeLabel} · ân hạn ${shift.lateGraceMinutes} phút',
        status: 'none',
        statusLabel: 'Chưa chấm công',
        blockedNote: blockedByShift == null ? null : 'Đang trong $blockedByShift chưa check-out',
      );
    }
    return ShiftCardView(
      title: shift.name,
      subtitle: shift.rangeLabel,
      status: a.status,
      statusLabel: StatusColors.label(a.status),
      showTimes: true,
      isOpen: a.isOpen,
      checkIn: Fmt.time(a.checkInAt),
      checkOut: a.checkOutAt == null ? null : Fmt.time(a.checkOutAt!),
      hours: a.isOpen ? null : Fmt.hours(a.workedHours),
      openCaption: a.isOpen ? 'Vào ca lúc ${Fmt.time(a.checkInAt)} · chưa check-out' : null,
      lateLine: a.lateMinutes > 0 ? 'Đi trễ ${a.lateMinutes} phút · phạt ${Fmt.money(a.latePenalty)}' : null,
      suspiciousLine: (a.isSuspicious && a.suspiciousReason != null) ? 'Cảnh báo: ${a.suspiciousReason}' : null,
      payLine: a.isOpen ? null : 'Lương ca: ${Fmt.money(a.pay)}',
      footer: (a.isOpen && onCheckOut != null)
          ? SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: Key('today_checkout_${shift.id}'),
                onPressed: onCheckOut,
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Check-out ca này'),
              ),
            )
          : null,
    );
  }
}

/// Thẻ bản ghi chấm công ở tab Lịch sử (có khối ngày bên trái).
class HistoryRecordCard extends StatelessWidget {
  final Attendance record;

  const HistoryRecordCard({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = StatusColors.of(context, record.status);
    final ink = StatusColors.textColor(context, color);
    final dateBlock = Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Column(
        children: [
          Text(Fmt.weekdayShort(record.workDate), style: text.labelMedium?.copyWith(color: ink)),
          Text(
            '${record.workDate.day}',
            style: text.titleLarge?.copyWith(color: ink, fontWeight: FontWeight.w800),
          ),
          Text('/${record.workDate.month}', style: text.labelSmall?.copyWith(color: ink)),
        ],
      ),
    );
    return ShiftCardView(
      title: record.shiftName ?? 'Ca làm',
      status: record.status,
      statusLabel: StatusColors.label(record.status),
      leading: dateBlock,
      showTimes: true,
      isOpen: record.isOpen,
      checkIn: Fmt.time(record.checkInAt),
      checkOut: record.checkOutAt == null ? null : Fmt.time(record.checkOutAt!),
      hours: record.isOpen ? null : Fmt.hours(record.workedHours),
      openCaption: record.isOpen ? 'Vào ${Fmt.time(record.checkInAt)} · chưa check-out' : null,
      lateLine: record.lateMinutes > 0 ? 'Trễ ${record.lateMinutes} phút · phạt ${Fmt.money(record.latePenalty)}' : null,
      suspiciousLine: (record.isSuspicious && record.suspiciousReason != null) ? 'Cảnh báo: ${record.suspiciousReason}' : null,
      payLine: record.isOpen ? null : 'Lương ca: ${Fmt.money(record.pay)}',
    );
  }
}
