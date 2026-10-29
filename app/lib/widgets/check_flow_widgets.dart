import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import 'auth_widgets.dart';
import 'ui_kit.dart';

/// Thanh 3 bước của luồng chấm công. Vòng 40px: xong = xanh + tick, đang làm = primary có quầng sáng,
/// chưa tới = viền mờ. [errorStep] (nếu có) tô đỏ.
class StepperBar extends StatelessWidget {
  final int current; // 0..labels.length-1
  final List<String> labels;
  final List<IconData> icons;
  final int? errorStep;

  const StepperBar({super.key, required this.current, required this.labels, required this.icons, this.errorStep});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = StatusColors.of(context, 'on-time');
    final n = labels.length;

    Widget circle(int i) {
      final isDone = i < current;
      final isCurrent = i == current;
      final isError = errorStep == i;
      final Color bg = isError ? scheme.error : (isDone ? done : (isCurrent ? scheme.primary : scheme.surface));
      final Color fg = (isDone || isCurrent || isError) ? Colors.white : scheme.outline;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: (isDone || isCurrent || isError) ? Colors.transparent : scheme.outlineVariant, width: 2),
          boxShadow: isCurrent && !isError
              ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 3)]
              : const [],
        ),
        child: Icon(isDone ? Icons.check_rounded : (isError ? Icons.close_rounded : icons[i]), size: 20, color: fg),
      );
    }

    Widget label(int i) => SizedBox(
      width: 76,
      child: Text(
        labels[i],
        key: Key('flow_step_label_$i'),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: i == current ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );

    return Row(
      key: const Key('flow_stepbar'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < n; i++) ...[
          Semantics(
            label: 'Bước ${i + 1} trên $n: ${labels[i]}',
            child: ExcludeSemantics(
              child: SizedBox(width: 76, child: Column(children: [circle(i), const SizedBox(height: 6), label(i)])),
            ),
          ),
          if (i < n - 1)
            Expanded(
              child: Padding(
                // 19 = tâm vòng tròn (20) - nửa độ dày đường nối (1)
                padding: const EdgeInsets.only(top: 19),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: i < current ? 1 : 0),
                  duration: const Duration(milliseconds: 350),
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: SizedBox(
                      height: 2,
                      child: Stack(
                        children: [
                          Container(color: scheme.outlineVariant),
                          FractionallySizedBox(
                            widthFactor: v,
                            child: Container(color: done),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// Lớp phủ khung ngắm QR phủ TRÊN khung camera: nền tối khoét ô vuông bo 20, 4 góc, đường quét chạy lên xuống.
/// [detected] = true thì 4 góc đổi xanh.
class QrScanOverlay extends StatefulWidget {
  final bool detected;

  const QrScanOverlay({super.key, this.detected = false});

  @override
  State<QrScanOverlay> createState() => _QrScanOverlayState();
}

class _QrScanOverlayState extends State<QrScanOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = StatusColors.of(context, 'on-time');
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _QrOverlayPainter(
            corner: widget.detected ? good : scheme.primary,
            progress: Curves.easeInOut.transform(_c.value),
            showLine: !widget.detected,
          ),
        ),
      ),
    );
  }
}

class _QrOverlayPainter extends CustomPainter {
  final Color corner;
  final double progress;
  final bool showLine;

  const _QrOverlayPainter({required this.corner, required this.progress, required this.showLine});

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(260.0, size.shortestSide * 0.7);
    final rect = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    final dim = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.55));

    final p = Paint()
      ..color = corner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 28.0;
    const r = 20.0;
    void cornerPath(Offset c, double dx, double dy) {
      final path = Path()
        ..moveTo(c.dx, c.dy + dy * len)
        ..lineTo(c.dx, c.dy + dy * r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + dx * r, c.dy)
        ..lineTo(c.dx + dx * len, c.dy);
      canvas.drawPath(path, p);
    }

    cornerPath(rect.topLeft, 1, 1);
    cornerPath(rect.topRight, -1, 1);
    cornerPath(rect.bottomLeft, 1, -1);
    cornerPath(rect.bottomRight, -1, -1);

    if (showLine) {
      final y = rect.top + 12 + (rect.height - 24) * progress;
      canvas.drawLine(
        Offset(rect.left + 14, y),
        Offset(rect.right - 14, y),
        Paint()
          ..color = corner.withValues(alpha: 0.85)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_QrOverlayPainter old) => old.corner != corner || old.progress != progress || old.showLine != showLine;
}

/// Thẻ trạng thái GPS: đang lấy (sóng lan tỏa) / thành công (tick + vĩ độ, kinh độ) / lỗi (kèm Thử lại).
class GpsStatusCard extends StatefulWidget {
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final double? latitude;
  final double? longitude;
  final bool mocked;
  final Key? retryKey;

  const GpsStatusCard({
    super.key,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.latitude,
    this.longitude,
    this.mocked = false,
    this.retryKey,
  });

  @override
  State<GpsStatusCard> createState() => _GpsStatusCardState();
}

class _GpsStatusCardState extends State<GpsStatusCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    if (widget.loading && widget.errorMessage == null) _c.repeat();
  }

  @override
  void didUpdateWidget(GpsStatusCard old) {
    super.didUpdateWidget(old);
    final active = widget.loading && widget.errorMessage == null;
    if (active && !_c.isAnimating) _c.repeat();
    if (!active && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasError = widget.errorMessage != null;
    final ok = !widget.loading && !hasError && widget.latitude != null && widget.longitude != null;
    final color = hasError ? scheme.error : (ok ? StatusColors.of(context, 'on-time') : scheme.primary);

    final Widget visual = SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!hasError && !ok)
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  for (final shift in const [0.0, 0.5])
                    Builder(
                      builder: (_) {
                        final t = (_c.value + shift) % 1.0;
                        return Container(
                          width: 56 + 64 * t,
                          height: 56 + 64 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withValues(alpha: 0.18 * (1 - t)),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          IconCircle(
            icon: hasError ? Icons.location_off_rounded : (ok ? Icons.check_rounded : Icons.my_location_rounded),
            color: color,
            size: 64,
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        visual,
        const SizedBox(height: 12),
        if (!ok) Text('Đang xác định vị trí', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        if (ok) ...[
          Text(
            'Đã lấy vị trí (${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)})',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Coord(label: 'Vĩ độ', value: widget.latitude!.toStringAsFixed(5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Coord(label: 'Kinh độ', value: widget.longitude!.toStringAsFixed(5)),
              ),
            ],
          ),
        ],
        if (widget.mocked) ...[
          const SizedBox(height: 12),
          const MessageBanner(
            message: 'Thiết bị báo vị trí GIẢ (mock location). Lần chấm công này sẽ bị đánh dấu nghi ngờ.',
            icon: Icons.warning_amber_rounded,
          ),
        ],
        if (hasError) ...[
          const SizedBox(height: 16),
          MessageBanner(message: widget.errorMessage!),
          if (widget.onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: widget.retryKey,
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _Coord extends StatelessWidget {
  final String label;
  final String value;

  const _Coord({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          Text(value, style: AppTypography.metric(context, size: 15)),
        ],
      ),
    );
  }
}

/// Mức độ của biên lai kết quả.
enum ReceiptTone { success, warning, danger }

/// Biên lai kết quả chấm công. [message] hiển thị NGUYÊN VĂN từ server.
class CheckResultReceipt extends StatefulWidget {
  final ReceiptTone tone;
  final String title;
  final String message;
  final List<Widget> rows; // thường là ReceiptRow
  final String? dangerReason; // khung đỏ nhạt khi bị từ chối

  const CheckResultReceipt({
    super.key,
    required this.tone,
    required this.title,
    required this.message,
    this.rows = const [],
    this.dangerReason,
  });

  @override
  State<CheckResultReceipt> createState() => _CheckResultReceiptState();
}

class _CheckResultReceiptState extends State<CheckResultReceipt> {
  @override
  void initState() {
    super.initState();
    if (widget.tone == ReceiptTone.success) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.tone) {
      ReceiptTone.success => StatusColors.of(context, 'on-time'),
      ReceiptTone.warning => StatusColors.of(context, 'late'),
      ReceiptTone.danger => StatusColors.of(context, 'suspicious'),
    };
    final icon = switch (widget.tone) {
      ReceiptTone.success => Icons.check_rounded,
      ReceiptTone.warning => Icons.priority_high_rounded,
      ReceiptTone.danger => Icons.close_rounded,
    };
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (context, v, child) => Transform.scale(scale: v.clamp(0.0, 1.3), child: child),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: Icon(icon, size: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (widget.dangerReason != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              widget.dangerReason!,
              key: const Key('flow_failure_message'),
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(color: StatusColors.textColor(context, color)),
            ),
          )
        else
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: StatusColors.textColor(context, color)),
          ),
        if (widget.rows.isNotEmpty) ...[
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(children: widget.rows),
            ),
          ),
        ],
      ],
    );
  }
}
