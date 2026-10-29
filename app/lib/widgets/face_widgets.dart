import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Màu viền oval: xanh = đúng 1 khuôn mặt, đỏ = nhiều mặt / lỗi, trung tính = chưa thấy mặt.
enum FaceOvalTone { neutral, good, bad }

/// Lớp phủ hiển thị khung oval hướng dẫn trên khung camera (CHỈ hiển thị, không ảnh hưởng điều kiện đạt).
/// Nền tối 60% khoét oval rộng 65% bề ngang tỉ lệ 1:1.35, tâm ở 40% chiều cao; viền 3px đổi màu mượt;
/// nhãn hướng dẫn dạng viên thuốc bên dưới oval kèm số giây đếm ngược.
class FaceOvalOverlay extends StatelessWidget {
  final FaceOvalTone tone;
  final String hint;
  final int? secondsLeft;

  const FaceOvalOverlay({super.key, required this.tone, required this.hint, this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    final target = switch (tone) {
      FaceOvalTone.good => StatusColors.of(context, 'on-time'),
      FaceOvalTone.bad => StatusColors.of(context, 'suspicious'),
      FaceOvalTone.neutral => Colors.white.withValues(alpha: 0.85),
    };
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        var ow = w * 0.65;
        var oh = ow * 1.35;
        if (oh > h * 0.78) {
          oh = h * 0.78;
          ow = oh / 1.35;
        }
        final cy = h * 0.4;
        final pillTop = (cy + oh / 2 + 12).clamp(0.0, h - 48.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: target),
                duration: const Duration(milliseconds: 250),
                builder: (context, color, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _OvalPainter(
                    color: color ?? target,
                    oval: Rect.fromCenter(center: Offset(w / 2, cy), width: ow, height: oh),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: pillTop,
              child: Semantics(
                liveRegion: true,
                label: hint,
                child: ExcludeSemantics(
                  child: Center(
                    child: Container(
                      key: const Key('face_hint'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              hint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (secondsLeft != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${secondsLeft}s',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w700,
                                fontFeatures: AppTypography.tabular,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OvalPainter extends CustomPainter {
  final Color color;
  final Rect oval;

  const _OvalPainter({required this.color, required this.oval});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_OvalPainter old) => old.color != color || old.oval != oval;
}

/// Thanh tiến trình mượt + danh sách các bước thử thách (tick xanh khi xong).
/// [steps] truyền ĐỘNG theo thử thách ngẫu nhiên của engine (bước đầu "Nhìn thẳng" + các hành động).
class LivenessChecklist extends StatelessWidget {
  final List<String> steps;
  final int completedSteps;
  final bool failed;
  final double progress;
  final Key? progressKey;

  const LivenessChecklist({
    super.key,
    required this.steps,
    required this.completedSteps,
    required this.progress,
    this.failed = false,
    this.progressKey,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = completedSteps.clamp(0, steps.length);
    final good = StatusColors.of(context, 'on-time');
    final bad = StatusColors.of(context, 'suspicious');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 300),
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(key: progressKey, value: v, minHeight: 8, color: failed ? bad : null),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < steps.length; i++)
          Builder(
            builder: (context) {
              final isDone = i < done;
              final isActive = i == done && !failed;
              final isFailed = failed && i == done;
              final Color color = isFailed ? bad : (isDone ? good : (isActive ? scheme.primary : scheme.outline));
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Semantics(
                  label: '${steps[i]}: ${isDone ? 'đã xong' : (isFailed ? 'hết thời gian' : (isActive ? 'đang thực hiện' : 'chưa tới'))}',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            isDone
                                ? Icons.check_circle_rounded
                                : (isFailed
                                      ? Icons.cancel_rounded
                                      : (isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded)),
                            key: ValueKey('$i-$isDone-$isFailed-$isActive'),
                            size: 22,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            steps[i],
                            style: TextStyle(
                              fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w500,
                              color: isDone ? scheme.onSurface : (isActive ? scheme.primary : scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                        if (isFailed)
                          Text(
                            'Hết thời gian',
                            style: TextStyle(color: StatusColors.textColor(context, bad), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
