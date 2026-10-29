import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_kit.dart';
import 'change_password_screen.dart';

/// Tab Hồ sơ: thông tin cá nhân, lương tạm tính tháng này, sửa họ tên, đổi mật khẩu, đăng xuất.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa họ tên'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('profile_name_field'),
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Họ và tên không được để trống' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            key: const Key('profile_name_save'),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    // Không dispose controller ngay: dialog còn đang chạy animation đóng
    if (name == null || name == current || !context.mounted) return;
    final profile = context.read<ProfileProvider>();
    final auth = context.read<AuthProvider>();
    final ok = await guardAction(context, () => profile.updateName(name), success: 'Đã cập nhật họ tên');
    if (ok) await auth.updateFullName(name);
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ cần đăng nhập và nhập OTP lại.',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (ok && context.mounted) await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProfileProvider>();
    final user = p.user;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = p.summary;

    return AsyncBody(
      loading: p.loading,
      error: p.error,
      isEmpty: user == null,
      onRefresh: p.load,
      emptyView: const EmptyView(icon: Icons.person_off_outlined, title: 'Không tải được hồ sơ'),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    AppAvatar(name: user.fullName, size: 80),
                    const SizedBox(height: 14),
                    Text(
                      user.fullName,
                      key: const Key('profile_fullname'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Pill(
                      label: roleLabel(user.role),
                      color: scheme.primary,
                      icon: user.role == 'admin' ? Icons.admin_panel_settings_rounded : Icons.badge_outlined,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user.email,
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text('@${user.username}', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const Key('profile_edit_name'),
                      onPressed: () => _editName(context, user.fullName),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Sửa họ tên'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lương tạm tính tháng ${p.month.month}/${p.month.year}',
                      style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.money(s.netPay),
                      key: const Key('profile_net_pay'),
                      style: text.headlineMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    ReceiptRow(label: 'Lương theo giờ', value: Fmt.money(user.hourlyRate)),
                    ReceiptRow(label: 'Ngày công', value: '${s.daysWorked}'),
                    ReceiptRow(label: 'Tổng giờ làm', value: Fmt.hours(s.totalHours)),
                    ReceiptRow(label: 'Tiền lương trước phạt', value: Fmt.money(s.grossPay)),
                    ReceiptRow(label: 'Tiền phạt đi trễ', value: '- ${Fmt.money(s.totalPenalty)}'),
                    ReceiptRow(label: 'Số lần đi trễ', value: '${s.lateCount} (${s.totalLateMinutes} phút)'),
                    const SizedBox(height: 6),
                    Text(
                      'Lương tạm tính chỉ gồm các ca đã check-out và có thể thay đổi nếu quản trị viên điều chỉnh.',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('profile_change_password'),
                    leading: IconCircle(icon: Icons.lock_reset_rounded, color: scheme.primary, size: 36),
                    title: const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen())),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('profile_logout'),
                    leading: IconCircle(icon: Icons.logout_rounded, color: scheme.error, size: 36),
                    title: Text(
                      'Đăng xuất',
                      style: TextStyle(fontWeight: FontWeight.w600, color: scheme.error),
                    ),
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
