import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/shift.dart';
import '../../providers/admin_providers.dart';
import '../../services/api_client.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/qr_standee.dart';
import '../../widgets/state_views.dart';
import 'shift_form_screen.dart';

/// Chi tiết ca: QR lớn chứa đúng `qrToken` (chuỗi thuần) để nhân viên quét khi chấm công.
/// Có mã dạng chữ để nhập tay, nút Sửa / Đổi mã QR / Xóa.
class ShiftDetailScreen extends StatelessWidget {
  final int shiftId;

  const ShiftDetailScreen({super.key, required this.shiftId});

  Future<void> _regenerate(BuildContext context, Shift shift) async {
    final ok = await confirmDialog(
      context,
      title: 'Đổi mã QR?',
      message: 'Mã QR cũ của "${shift.name}" sẽ hết hiệu lực ngay. Bạn cần in/hiển thị lại mã mới cho nhân viên.',
      confirmLabel: 'Đổi mã',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await guardAction(context, () => context.read<ShiftsProvider>().regenerateQr(shift.id), success: 'Đã tạo mã QR mới');
  }

  Future<void> _delete(BuildContext context, Shift shift) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa ca làm việc?',
      message: 'Xóa vĩnh viễn "${shift.name}". Không thể hoàn tác.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final provider = context.read<ShiftsProvider>();
    final navigator = Navigator.of(context);
    try {
      await provider.delete(shift.id);
      if (context.mounted) {
        showAppSnack(context, 'Đã xóa ca ${shift.name}');
        navigator.pop();
      }
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.statusCode == 409 && shift.isActive) {
        // Đã có chấm công: gợi ý tạm dừng ca thay vì xóa
        final pause = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Không thể xóa'),
            content: Text('${e.message}\n\nBạn có muốn tạm dừng ca này thay vì xóa?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
              FilledButton(
                key: const Key('delete_conflict_pause'),
                style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tạm dừng ca'),
              ),
            ],
          ),
        );
        if (pause == true && context.mounted) {
          await guardAction(
            context,
            () => provider.update(
              shift.id,
              name: shift.name,
              startTime: shift.startLabel,
              endTime: shift.endLabel,
              lateGraceMinutes: shift.lateGraceMinutes,
              isActive: false,
            ),
            success: 'Đã tạm dừng ca',
          );
        }
      } else {
        showAppSnack(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shift = context.watch<ShiftsProvider>().byId(shiftId);
    if (shift == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(title: 'Không tìm thấy ca làm việc'),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final token = shift.qrToken ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(shift.name),
        actions: [
          IconButton(
            key: const Key('shift_edit'),
            tooltip: 'Sửa ca',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ShiftFormScreen(shift: shift))),
          ),
          IconButton(
            key: const Key('shift_delete'),
            tooltip: 'Xóa ca',
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            onPressed: () => _delete(context, shift),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: Text('${shift.rangeLabel}  ·  ân hạn ${shift.lateGraceMinutes} phút', style: text.titleMedium)),
            const SizedBox(height: 4),
            Center(
              child: Pill(
                label: shift.isActive ? 'Đang hoạt động' : 'Tạm dừng (không chấm công được)',
                color: shift.isActive ? scheme.primary : scheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            QrStandeeCard(shiftName: shift.name, token: token),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('shift_regenerate'),
                onPressed: () => _regenerate(context, shift),
                icon: const Icon(Icons.autorenew_rounded),
                label: const Text('Đổi mã QR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
