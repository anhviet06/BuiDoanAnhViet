import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Icon trong vòng tròn nền tint (dùng ở thẻ số liệu, trạng thái rỗng/lỗi...).
class IconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconCircle({super.key, required this.icon, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Avatar tròn gradient với chữ cái đầu của TỪ CUỐI trong họ tên.
class AppAvatar extends StatelessWidget {
  final String name;
  final double size;

  const AppAvatar({super.key, required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [AppColors.brandDeep, AppColors.brandLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(
        avatarInitial(name),
        style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Tiêu đề nhóm nội dung.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({super.key, required this.title, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 8)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Một ô số liệu trong [MetricGrid].
class MetricItem {
  final Key? key;
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final Color? color;
  final VoidCallback? onTap;

  const MetricItem({
    this.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.color,
    this.onTap,
  });
}

/// Thẻ số liệu: icon trong vòng tròn tint, nhãn nhỏ, số lớn đậm (tabular, co lại nếu dài).
class MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final Color? color;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    final tint = highlight ? scheme.primary.withValues(alpha: 0.08) : scheme.surfaceContainerLow;
    final card = Card(
      color: tint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: highlight ? scheme.primary.withValues(alpha: 0.3) : scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconCircle(icon: icon, color: accent, size: 34),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500, height: 1.25),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, style: AppTypography.metric(context, size: highlight ? 24 : 20)),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(child: card),
    );
  }
}

/// Lưới số liệu kiểu bento: thẻ highlight full-width ở đầu, các thẻ còn lại 3 một hàng
/// (màn hẹp hoặc chữ lớn thì 2 cột). Không dùng GridView để chiều cao theo nội dung.
class MetricGrid extends StatelessWidget {
  final List<MetricItem> items;

  const MetricGrid({super.key, required this.items});

  Widget _card(MetricItem i) =>
      MetricCard(key: i.key, icon: i.icon, label: i.label, value: i.value, highlight: i.highlight, color: i.color, onTap: i.onTap);

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, c) {
        final perRow = (c.maxWidth < 340 || scale > 1.15) ? 2 : 3;
        final rows = <Widget>[];
        final highlighted = items.where((i) => i.highlight).toList();
        final rest = items.where((i) => !i.highlight).toList();
        for (final h in highlighted) {
          rows.add(SizedBox(width: double.infinity, child: _card(h)));
        }
        for (var s = 0; s < rest.length; s += perRow) {
          final chunk = rest.sublist(s, (s + perRow).clamp(0, rest.length));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var k = 0; k < perRow; k++) ...[
                    if (k > 0) const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(child: k < chunk.length ? _card(chunk[k]) : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: AppSpacing.sm + 2), rows[i]],
          ],
        );
      },
    );
  }
}

/// Một dòng "nhãn xám bên trái - giá trị đậm bên phải" (biên lai, chi tiết).
class ReceiptRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color? valueColor;

  const ReceiptRow({super.key, required this.label, this.value, this.valueWidget, this.valueColor})
    : assert(value != null || valueWidget != null);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: value != null ? '$label: $value' : label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
            const SizedBox(width: 16),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child:
                    valueWidget ??
                    Text(
                      value!,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: valueColor ?? scheme.onSurface,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung xương tải dữ liệu có hiệu ứng ánh sáng chạy ngang (tự viết, không thêm package).
class SkeletonLoader extends StatefulWidget {
  final int count;
  final double itemHeight;

  const SkeletonLoader({super.key, this.count = 4, this.itemHeight = 96});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final glow = Color.lerp(base, scheme.surfaceContainerLow, 0.8)!;
    return Semantics(
      label: 'Đang tải',
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final gradient = LinearGradient(
              begin: Alignment(-1.5 + 3 * _c.value, 0),
              end: Alignment(-0.5 + 3 * _c.value, 0),
              colors: [base, glow, base],
            );
            return ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: widget.count,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => Container(
                height: widget.itemHeight,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), gradient: gradient),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Khung cảnh báo ca nghi ngờ: nền danger nhạt, icon cờ, dòng chính + dòng phụ, nút hành động.
/// Màn hẹp / chữ lớn thì nút xuống dòng.
class SuspiciousBanner extends StatelessWidget {
  final String message;
  final String? caption;
  final String actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  const SuspiciousBanner({super.key, required this.message, this.caption, this.actionLabel = 'Xử lý', this.onAction, this.actionKey});

  @override
  Widget build(BuildContext context) {
    final base = StatusColors.of(context, 'suspicious');
    final ink = StatusColors.textColor(context, base);
    final button = onAction == null
        ? null
        : OutlinedButton(
            key: actionKey,
            onPressed: onAction,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: ink, side: BorderSide(color: base)),
            child: Text(actionLabel),
          );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: base.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(1) > 1.15;
          final info = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_rounded, size: 22, color: base),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: TextStyle(color: ink, fontWeight: FontWeight.w600, height: 1.3)),
                    if (caption != null) Text(caption!, style: TextStyle(color: base, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
            ],
          );
          if (button == null) return info;
          if (stacked) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 10), button]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: info), const SizedBox(width: 10), button]);
        },
      ),
    );
  }
}
