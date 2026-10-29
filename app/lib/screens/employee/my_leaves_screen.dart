import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/leave_request.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/leave_card.dart';
import '../../widgets/state_views.dart';
import 'leave_form_screen.dart';

/// Tab Nghỉ phép: đơn của mình; sửa/xóa chỉ khi đơn còn "Chờ duyệt".
class MyLeavesScreen extends StatelessWidget {
  const MyLeavesScreen({super.key});

  Future<void> _delete(BuildContext context, LeaveRequest leave) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa đơn nghỉ phép?',
      message: 'Đơn ${Fmt.date(leave.fromDate)} - ${Fmt.date(leave.toDate)} sẽ bị xóa.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await guardAction(context, () => context.read<MyLeavesProvider>().delete(leave.id), success: 'Đã xóa đơn nghỉ phép');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MyLeavesProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('leave_add'),
        heroTag: null,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LeaveFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo đơn nghỉ'),
      ),
      body: AsyncBody(
        loading: p.loading,
        error: p.error,
        isEmpty: p.leaves.isEmpty,
        onRefresh: p.load,
        emptyView: const EmptyView(
          icon: Icons.beach_access_outlined,
          title: 'Bạn chưa có đơn nghỉ phép',
          subtitle: 'Bấm "Tạo đơn nghỉ" để gửi đơn cho quản trị viên.',
        ),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: p.leaves.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final leave = p.leaves[i];
            return _LeaveCard(
              leave: leave,
              onEdit: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => LeaveFormScreen(leave: leave))),
              onDelete: () => _delete(context, leave),
            );
          },
        ),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final LeaveRequest leave;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LeaveCard({required this.leave, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LeaveRequestCard(
      dateRange: '${Fmt.date(leave.fromDate)} - ${Fmt.date(leave.toDate)}',
      durationText: '${leave.days} ngày',
      reason: leave.reason,
      status: leave.status,
      adminNote: (leave.adminNote != null && leave.adminNote!.isNotEmpty) ? 'Phản hồi: ${leave.adminNote}' : null,
      // Chỉ đơn còn chờ duyệt mới sửa/xóa được
      actions: leave.isPending
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('leave_edit_${leave.id}'),
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Sửa'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('leave_delete_${leave.id}'),
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Xóa'),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
