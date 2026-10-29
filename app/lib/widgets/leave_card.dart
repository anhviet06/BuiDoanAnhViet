import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common_widgets.dart';
import 'ui_kit.dart';

/// Thẻ đơn nghỉ phép (phần HIỂN THỊ THUẦN). Dùng cho nhân viên (có Sửa/Xóa) và admin (có tên + Duyệt/Từ chối).
/// Thanh màu mảnh bên trái theo trạng thái. Lý do dài thì thu gọn 3 dòng, chạm để xem đủ.
class LeaveRequestCard extends StatefulWidget {
  final String dateRange;
  final String? durationText;
  final String reason;
  final String status; // pending | approved | rejected
  final String? adminNote; // chuỗi đã định dạng sẵn (ví dụ "Phản hồi: ...")
  final String? employeeName;
  final Widget? actions;

  const LeaveRequestCard({
    super.key,
    required this.dateRange,
    required this.reason,
    required this.status,
    this.durationText,
    this.adminNote,
    this.employeeName,
    this.actions,
  });

  @override
  State<LeaveRequestCard> createState() => _LeaveRequestCardState();
}

class _LeaveRequestCardState extends State<LeaveRequestCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = StatusColors.of(context, widget.status);
    final note = widget.adminNote;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.employeeName != null) ...[
                      Row(
                        children: [
                          AppAvatar(name: widget.employeeName!, size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.employeeName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Flexible(child: Pill(label: StatusColors.label(widget.status), color: color)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.date_range_rounded, size: 18, color: scheme.primary),
                          const SizedBox(width: 6),
                          Expanded(child: Text(widget.dateRange, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ] else
                      Row(
                        children: [
                          IconCircle(icon: Icons.date_range_rounded, color: scheme.primary, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.dateRange, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                if (widget.durationText != null) Text(widget.durationText!, style: AppTypography.subtitle(context)),
                              ],
                            ),
                          ),
                          Flexible(child: Pill(label: StatusColors.label(widget.status), color: color)),
                        ],
                      ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          widget.reason,
                          maxLines: _expanded ? null : 3,
                          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                      ),
                    ),
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ghi chú của admin', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(note, style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                    if (widget.actions != null) ...[const SizedBox(height: 12), widget.actions!],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
