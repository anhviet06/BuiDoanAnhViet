import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../providers/admin_providers.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_kit.dart';
import 'user_form_screen.dart';

/// Tab Nhân viên: danh sách, tìm kiếm, thêm/sửa, khóa/mở, đặt lại mật khẩu, xóa.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _query = '';

  Future<void> _openForm([AppUser? user]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UserFormScreen(user: user)));

  Future<void> _toggleLock(AppUser user) async {
    final lock = !user.isLocked;
    final ok = await confirmDialog(
      context,
      title: lock ? 'Khóa tài khoản?' : 'Mở khóa tài khoản?',
      message: lock
          ? '${user.fullName} sẽ không đăng nhập hoặc chấm công được cho tới khi được mở khóa.'
          : '${user.fullName} sẽ có thể đăng nhập và chấm công trở lại.',
      confirmLabel: lock ? 'Khóa' : 'Mở khóa',
      destructive: lock,
    );
    if (!ok || !mounted) return;
    await guardAction(context, () => context.read<UsersProvider>().setLocked(user.id, lock),
        success: lock ? 'Đã khóa tài khoản' : 'Đã mở khóa tài khoản');
  }

  Future<void> _resetPassword(AppUser user) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đặt lại mật khẩu'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nhập mật khẩu mới cho ${user.fullName}. Hãy báo cho nhân viên để họ tự đổi sau.'),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('reset_password_field'),
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                validator: (v) => (v == null || v.length < 6) ? 'Mật khẩu tối thiểu 6 ký tự' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            key: const Key('reset_password_submit'),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, ctrl.text);
            },
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );
    // Không dispose ngay: dialog còn đang chạy animation đóng và vẫn dùng controller này
    if (pw == null || !mounted) return;
    await guardAction(context, () => context.read<UsersProvider>().resetPassword(user.id, pw),
        success: 'Đã đặt lại mật khẩu');
  }

  Future<void> _delete(AppUser user) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa nhân viên?',
      message: 'Xóa vĩnh viễn ${user.fullName} cùng các đơn nghỉ phép của họ. Không thể hoàn tác.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final provider = context.read<UsersProvider>();
    try {
      await provider.delete(user.id);
      if (mounted) showAppSnack(context, 'Đã xóa ${user.fullName}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // Đã có chấm công: gợi ý dùng Khóa thay vì xóa
        final lock = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Không thể xóa'),
            content: Text('${e.message}\n\nBạn có muốn khóa tài khoản này thay vì xóa?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
              FilledButton(
                key: const Key('delete_conflict_lock'),
                style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Khóa tài khoản'),
              ),
            ],
          ),
        );
        if (lock == true && mounted && !user.isLocked) {
          await guardAction(context, () => provider.setLocked(user.id, true), success: 'Đã khóa tài khoản');
        }
      } else {
        showAppSnack(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<UsersProvider>();
    final myId = context.read<AuthProvider>().session?.userId;
    final q = _query.trim().toLowerCase();
    final shown = p.users
        .where((u) =>
            q.isEmpty ||
            u.fullName.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('users_add'),
        heroTag: null,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Thêm nhân viên'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('users_search'),
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên, email, tên đăng nhập',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: AsyncBody(
              loading: p.loading,
              error: p.error,
              isEmpty: shown.isEmpty,
              onRefresh: p.load,
              emptyView: EmptyView(
                icon: Icons.groups_outlined,
                title: q.isEmpty ? 'Chưa có nhân viên' : 'Không tìm thấy kết quả',
                subtitle: q.isEmpty ? 'Bấm "Thêm nhân viên" để tạo tài khoản đầu tiên.' : 'Thử từ khóa khác.',
              ),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _UserCard(
                  user: shown[i],
                  isMe: shown[i].id == myId,
                  onEdit: () => _openForm(shown[i]),
                  onToggleLock: () => _toggleLock(shown[i]),
                  onResetPassword: () => _resetPassword(shown[i]),
                  onDelete: () => _delete(shown[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _UserAction { edit, lock, password, delete }

class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool isMe;
  final VoidCallback onEdit;
  final VoidCallback onToggleLock;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.isMe,
    required this.onEdit,
    required this.onToggleLock,
    required this.onResetPassword,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: user.isLocked ? 0.65 : 1,
      child: Card(
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AppAvatar(name: user.fullName, size: 48),
                    if (user.isLocked)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
                          child: Icon(Icons.lock_rounded, size: 14, color: scheme.error),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? '${user.fullName} (bạn)' : user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text('@${user.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Pill(label: roleLabel(user.role), color: user.isAdmin ? scheme.tertiary : scheme.primary),
                          if (!user.isAdmin) Pill(label: '${Fmt.money(user.hourlyRate)}/giờ', color: scheme.secondary),
                          if (user.isLocked) Pill(label: 'Đã khóa', color: scheme.error, icon: Icons.lock_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              PopupMenuButton<_UserAction>(
                key: Key('user_menu_${user.id}'),
                tooltip: 'Thao tác',
                onSelected: (a) => switch (a) {
                  _UserAction.edit => onEdit(),
                  _UserAction.lock => onToggleLock(),
                  _UserAction.password => onResetPassword(),
                  _UserAction.delete => onDelete(),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: _UserAction.edit, child: Text('Sửa thông tin')),
                  if (!isMe)
                    PopupMenuItem(value: _UserAction.lock, child: Text(user.isLocked ? 'Mở khóa' : 'Khóa tài khoản')),
                  const PopupMenuItem(value: _UserAction.password, child: Text('Đặt lại mật khẩu')),
                  if (!isMe) PopupMenuItem(value: _UserAction.delete, child: Text('Xóa', style: TextStyle(color: scheme.error))),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
