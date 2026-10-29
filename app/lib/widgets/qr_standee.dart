import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme.dart';
import 'state_views.dart';

/// Thẻ "bảng QR" của ca: tên ca, QR nền trắng LUÔN trắng (kể cả chế độ tối), nút Phóng to,
/// và mã nhập tay hiển thị NGUYÊN VĂN (chọn được, sao chép được). Nội dung QR = chính chuỗi `token`.
class QrStandeeCard extends StatelessWidget {
  final String shiftName;
  final String token;

  const QrStandeeCard({super.key, required this.shiftName, required this.token});

  static const _qrColor = Color(0xFF0F172A);

  static Widget qr(String token, double size, {Key? key}) => QrImageView(
        key: key,
        data: token,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        // Ô vuông (không bo tròn) để máy quét đọc ổn định
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _qrColor),
        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _qrColor),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl - 4),
        child: LayoutBuilder(
          builder: (context, c) {
            final size = math.min(c.maxWidth * 0.7, 280.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(shiftName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Quét mã để chấm công', textAlign: TextAlign.center, style: AppTypography.subtitle(context, size: 14)),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: token.isEmpty
                        ? SizedBox(width: size, height: size, child: const Center(child: Text('Không có mã QR', style: TextStyle(color: Colors.black54))))
                        : qr(token, size, key: ValueKey('shift_qr:$token')),
                  ),
                ),
                const SizedBox(height: 12),
                if (token.isNotEmpty)
                  Center(
                    child: TextButton.icon(
                      key: const Key('shift_zoom'),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _QrFullScreen(shiftName: shiftName, token: token))),
                      icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
                      label: const Text('Phóng to'),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('hoặc nhập mã', style: AppTypography.subtitle(context, size: 12))),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: SelectableText(
                    token,
                    key: const Key('shift_token_text'),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(fontFamily: 'monospace', letterSpacing: 1, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    key: const Key('shift_copy'),
                    onPressed: token.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: token));
                            if (context.mounted) showAppSnack(context, 'Đã sao chép mã');
                          },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Sao chép'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QrFullScreen extends StatelessWidget {
  final String shiftName;
  final String token;

  const _QrFullScreen({required this.shiftName, required this.token});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(shiftName),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, c) => QrStandeeCard.qr(token, math.min(math.min(c.maxWidth, c.maxHeight) - 32, 560)),
          ),
        ),
      ),
    );
  }
}
