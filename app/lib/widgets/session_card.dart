import 'package:flutter/material.dart';

import '../models/auth_session.dart';

/// Thẻ thông tin người đang đăng nhập (dùng tạm ở các trang chủ placeholder, sau này ở hồ sơ).
class SessionCard extends StatelessWidget {
  final AuthSession session;

  const SessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              child: Icon(session.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                  color: scheme.onPrimaryContainer, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.fullName, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(session.email, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(session.isAdmin ? 'Quản trị viên' : 'Nhân viên'),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: scheme.secondaryContainer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
