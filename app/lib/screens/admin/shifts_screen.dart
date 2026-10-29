import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/shift.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';
import 'shift_detail_screen.dart';
import 'shift_form_screen.dart';

/// Tab Ca làm: danh sách ca; bấm vào ca để xem QR chấm công.
class ShiftsScreen extends StatelessWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ShiftsProvider>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('shifts_add'),
        heroTag: null,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ShiftFormScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm ca'),
      ),
      body: AsyncBody(
        loading: p.loading,
        error: p.error,
        isEmpty: p.shifts.isEmpty,
        onRefresh: p.load,
        emptyView: const EmptyView(
          icon: Icons.schedule_outlined,
          title: 'Chưa có ca làm việc',
          subtitle: 'Bấm "Thêm ca" để tạo ca đầu tiên. Mỗi ca có một mã QR riêng để nhân viên quét khi chấm công.',
        ),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: p.shifts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ShiftCard(shift: p.shifts[i]),
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final Shift shift;

  const _ShiftCard({required this.shift});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        key: Key('shift_card_${shift.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => ShiftDetailScreen(shiftId: shift.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: shift.isActive ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.qr_code_2_rounded,
                    size: 30, color: shift.isActive ? scheme.onPrimaryContainer : scheme.outline),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shift.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(shift.rangeLabel, style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      Pill(label: 'Ân hạn ${shift.lateGraceMinutes} phút', color: scheme.secondary),
                      shift.isActive
                          ? Pill(label: 'Đang hoạt động', color: StatusColors.of(context, 'approved'))
                          : Pill(label: 'Tạm dừng', color: scheme.outline),
                    ]),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
