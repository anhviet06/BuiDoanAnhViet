import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/leave_request.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/leave_card.dart';
import '../../widgets/state_views.dart';

/// Tab Nghỉ phép: lọc theo trạng thái, duyệt / từ chối đơn (kèm ghi chú).
class LeavesScreen extends StatelessWidget {
  const LeavesScreen({super.key});

  static const _filters = <(String?, String)>[
    ('pending', 'Chờ duyệt'),
    ('approved', 'Đã duyệt'),
    ('rejected', 'Từ chối'),
    (null, 'Tất cả'),
  ];

  Future<void> _decide(BuildContext context, LeaveRequest leave, {required bool approve}) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Duyệt đơn nghỉ phép?' : 'Từ chối đơn nghỉ phép?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${leave.user?.fullName ?? 'Nhân viên'}: ${Fmt.date(leave.fromDate)} - ${Fmt.date(leave.toDate)} (${leave.days} ngày)'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('decision_note'),
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ghi chú cho nhân viên (tùy chọn)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            key: const Key('decision_confirm'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 44),
              backgroundColor: approve ? null : Theme.of(ctx).colorScheme.error,
              foregroundColor: approve ? null : Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Duyệt' : 'Từ chối'),
          ),
        ],
      ),
    );
    final note = noteCtrl.text.trim();
    // Không dispose ngay: dialog còn đang chạy animation đóng và vẫn dùng controller này
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<LeavesProvider>();
    await guardAction(
      context,
      () => approve
          ? provider.approve(leave.id, note: note.isEmpty ? null : note)
          : provider.reject(leave.id, note: note.isEmpty ? null : note),
      success: approve ? 'Đã duyệt đơn nghỉ phép' : 'Đã từ chối đơn nghỉ phép',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LeavesProvider>();
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              for (final (value, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('leave_filter_${value ?? 'all'}'),
                    label: Text(label),
                    selected: p.statusFilter == value,
                    onSelected: (_) => p.setFilter(value),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody(
            loading: p.loading,
            error: p.error,
            isEmpty: p.leaves.isEmpty,
            onRefresh: p.load,
            emptyView: EmptyView(
              icon: Icons.event_available_rounded,
              title: p.statusFilter == 'pending' ? 'Không có đơn chờ duyệt' : 'Không có đơn nghỉ phép',
              subtitle: 'Đơn nhân viên gửi sẽ hiện ở đây.',
            ),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: p.leaves.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _LeaveCard(
                leave: p.leaves[i],
                onApprove: () => _decide(context, p.leaves[i], approve: true),
                onReject: () => _decide(context, p.leaves[i], approve: false),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveRequest leave;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _LeaveCard({required this.leave, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LeaveRequestCard(
      employeeName: leave.user?.fullName ?? 'Nhân viên #${leave.userId}',
      dateRange: '${Fmt.date(leave.fromDate)} - ${Fmt.date(leave.toDate)}  (${leave.days} ngày)',
      reason: leave.reason,
      status: leave.status,
      adminNote: (leave.adminNote != null && leave.adminNote!.isNotEmpty) ? 'Ghi chú: ${leave.adminNote}' : null,
      actions: leave.isPending
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('leave_reject_${leave.id}'),
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                    ),
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: Key('leave_approve_${leave.id}'),
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    child: const Text('Duyệt'),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
