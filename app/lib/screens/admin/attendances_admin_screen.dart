import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/attendance.dart';
import '../../models/shift.dart';
import '../../providers/admin_providers.dart';
import '../../services/admin_services.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/shift_card.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_kit.dart';

/// Quản lý chấm công của admin: lọc theo nhân viên, khoảng ngày, trạng thái (nhất là "Nghi ngờ"),
/// và xử lý: "Gỡ cờ nghi ngờ" hoặc "Đóng ca" cho bản ghi quên check-out.
class AttendancesAdminScreen extends StatelessWidget {
  final int? userId;
  final DateTime from;
  final DateTime to;
  final String? status; // null = tất cả

  const AttendancesAdminScreen({super.key, this.userId, required this.from, required this.to, this.status});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => AdminAttendancesProvider(c.read<AdminAttendanceService>(), userId: userId, from: from, to: to, status: status)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Quản lý chấm công')),
        body: const _View(),
      ),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  static const _chips = <(String?, bool, String, String)>[
    // (status gửi server, chỉ chưa check-out, nhãn, key)
    (null, false, 'Tất cả', 'all'),
    ('suspicious', false, 'Nghi ngờ', 'suspicious'),
    ('late', false, 'Đi trễ', 'late'),
    ('on-time', false, 'Đúng giờ', 'on-time'),
    (null, true, 'Chưa check-out', 'open'),
  ];

  Future<void> _pickRange(BuildContext context, AdminAttendancesProvider p) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: p.from, end: p.to),
      helpText: 'Chọn khoảng ngày',
      saveText: 'Chọn',
    );
    if (picked != null) {
      await p.setFilters(from: DateTime(picked.start.year, picked.start.month, picked.start.day), to: DateTime(picked.end.year, picked.end.month, picked.end.day));
    }
  }

  Future<void> _review(BuildContext context, Attendance a) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gỡ cờ nghi ngờ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${a.userName ?? 'Nhân viên'} · ${Fmt.date(a.workDate)} · ${a.shiftName ?? ''}'),
            const SizedBox(height: 4),
            Text('Lý do bị nghi ngờ: ${a.suspiciousReason ?? '-'}', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              key: const Key('review_note'),
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            key: const Key('review_confirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ cờ'),
          ),
        ],
      ),
    );
    // Không dispose controller ngay: dialog còn đang chạy animation đóng
    if (ok != true || !context.mounted) return;
    final note = noteCtrl.text.trim();
    await guardAction(context, () => context.read<AdminAttendancesProvider>().review(a.id, note: note.isEmpty ? null : note),
        success: 'Đã gỡ cờ nghi ngờ');
  }

  Future<void> _close(BuildContext context, Attendance a) async {
    final noteCtrl = TextEditingController();
    // Mặc định giờ ra = giờ kết thúc ca
    var time = a.shiftEndTime == null ? const TimeOfDay(hour: 17, minute: 0) : Shift.parseTime(a.shiftEndTime!);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Đóng ca quên check-out'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${a.userName ?? 'Nhân viên'} · ${Fmt.date(a.workDate)} · ${a.shiftName ?? ''} (vào lúc ${Fmt.time(a.checkInAt)})'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('close_time'),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: time,
                    helpText: 'Giờ ra',
                    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
                  );
                  if (picked != null) setState(() => time = picked);
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.access_time_rounded),
                label: Text('Giờ ra: ${Shift.format(time)}', key: const Key('close_time_text')),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('close_note'),
                controller: noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            FilledButton(
              key: const Key('close_confirm'),
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đóng ca'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final note = noteCtrl.text.trim();
    await guardAction(
      context,
      () => context.read<AdminAttendancesProvider>().close(a.id, checkOutTime: Shift.format(time), note: note.isEmpty ? null : note),
      success: 'Đã đóng ca',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AdminAttendancesProvider>();
    final users = context.read<UsersProvider>().users.where((u) => !u.isAdmin).toList();
    final selectedUser = users.any((u) => u.id == p.userId) ? p.userId : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              DropdownButtonFormField<int?>(
                key: const Key('att_filter_user'),
                initialValue: selectedUser,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nhân viên', prefixIcon: Icon(Icons.person_outline_rounded)),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Tất cả nhân viên')),
                  for (final u in users) DropdownMenuItem<int?>(value: u.id, child: Text(u.fullName)),
                ],
                onChanged: (v) => p.setFilters(userId: () => v),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('att_filter_range'),
                onPressed: () => _pickRange(context, p),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.date_range_rounded),
                label: Text('${Fmt.date(p.from)} - ${Fmt.date(p.to)}', key: const Key('att_range_text')),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              for (final (status, open, label, key) in _chips)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('att_chip_$key'),
                    label: Text(label),
                    selected: p.openOnly == open && p.status == status,
                    onSelected: (_) => p.setFilters(status: () => status, openOnly: open),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody(
            loading: p.loading,
            error: p.error,
            isEmpty: p.records.isEmpty,
            onRefresh: p.load,
            emptyView: const EmptyView(
              icon: Icons.fact_check_outlined,
              title: 'Không có bản ghi chấm công',
              subtitle: 'Thử đổi nhân viên, khoảng ngày hoặc trạng thái.',
            ),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: p.records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _RecordCard(
                record: p.records[i],
                onReview: () => _review(context, p.records[i]),
                onClose: () => _close(context, p.records[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  final Attendance record;
  final VoidCallback onReview;
  final VoidCallback onClose;

  const _RecordCard({required this.record, required this.onReview, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = record;
    final name = r.userName ?? 'Nhân viên #${r.userId}';
    final faceOk = r.faceVerified;

    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(faceOk ? Icons.verified_user_rounded : Icons.person_off_outlined,
                size: 16, color: faceOk ? StatusColors.of(context, 'approved') : scheme.outline),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                faceOk ? 'Đã xác thực khuôn mặt${r.checkOutFaceVerified == false ? ' (lúc ra ca: chưa xác thực)' : ''}' : 'Chưa xác thực mặt',
                key: Key('att_face_${r.id}'),
                style: text.bodySmall?.copyWith(color: faceOk ? StatusColors.textOf(context, 'approved') : scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        if (r.adminAction != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${r.wasReviewed ? 'Admin đã gỡ cờ nghi ngờ' : 'Admin đã đóng ca'}${r.adminNote == null ? '' : ': ${r.adminNote}'}',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Cách công ty ${r.distanceMeters.round()} m', style: AppTypography.subtitle(context, size: 12)),
        ),
        if (r.isSuspicious || r.isOpen) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (r.isSuspicious)
                OutlinedButton.icon(
                  key: Key('att_review_${r.id}'),
                  onPressed: onReview,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Gỡ cờ nghi ngờ'),
                ),
              if (r.isOpen)
                OutlinedButton.icon(
                  key: Key('att_close_${r.id}'),
                  onPressed: onClose,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Đóng ca'),
                ),
            ],
          ),
        ],
      ],
    );

    return ShiftCardView(
      key: Key('att_card_${r.id}'),
      leading: AppAvatar(name: name, size: 40),
      title: name,
      subtitle: '${Fmt.weekdayShort(r.workDate)}, ${Fmt.date(r.workDate)} · ${r.shiftName ?? ''} ${r.shiftRange}',
      status: r.status,
      statusLabel: StatusColors.label(r.status),
      showTimes: true,
      isOpen: r.isOpen,
      checkIn: Fmt.time(r.checkInAt),
      checkOut: r.checkOutAt == null ? null : Fmt.time(r.checkOutAt!),
      hours: r.isOpen ? null : Fmt.hours(r.workedHours),
      openCaption: r.isOpen ? 'Vào ${Fmt.time(r.checkInAt)} · chưa check-out' : null,
      lateLine: r.lateMinutes > 0 ? 'Trễ ${r.lateMinutes} phút · phạt ${Fmt.money(r.latePenalty)}' : null,
      suspiciousLine: (r.isSuspicious && r.suspiciousReason != null) ? 'Nghi ngờ: ${r.suspiciousReason}' : null,
      payLine: r.isOpen ? null : 'Lương ca: ${Fmt.money(r.pay)}',
      footer: footer,
    );
  }
}
