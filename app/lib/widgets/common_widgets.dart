import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/api_client.dart';
import 'state_views.dart';
import 'ui_kit.dart';

/// Khung hiển thị một danh sách tải từ API với đủ 3 trạng thái: đang tải / lỗi (thử lại) / rỗng.
/// [child] phải là widget cuộn được (ListView) để kéo-làm-mới hoạt động.
class AsyncBody extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool isEmpty;
  final Future<void> Function() onRefresh;
  final Widget emptyView;
  final Widget child;

  const AsyncBody({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.onRefresh,
    required this.emptyView,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && isEmpty) return const SkeletonLoader();
    if (error != null && isEmpty) return ErrorView(message: error!, onRetry: onRefresh);
    if (isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, c) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: c.maxHeight, child: emptyView)],
          ),
        ),
      );
    }
    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }
}

/// Hộp thoại xác nhận. Trả true nếu người dùng đồng ý.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Đồng ý',
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(96, 44),
            backgroundColor: destructive ? scheme.error : null,
            foregroundColor: destructive ? scheme.onError : null,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Chạy một thao tác gọi API; lỗi thì hiện snackbar (message của server), thành công thì hiện [success].
/// Trả true nếu thành công.
Future<bool> guardAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (context.mounted && success != null) showAppSnack(context, success);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) showAppSnack(context, e.message, error: true);
  } catch (_) {
    if (context.mounted) showAppSnack(context, 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.', error: true);
  }
  return false;
}

/// Nhãn nhỏ dạng viên thuốc (vai trò, trạng thái...): nền tint 12%, viền 30%, chấm tròn (hoặc icon),
/// chữ làm đậm/sáng để đủ tương phản. [color] là màu gốc (chấm, viền).
class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const Pill({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final textColor = StatusColors.textColor(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
