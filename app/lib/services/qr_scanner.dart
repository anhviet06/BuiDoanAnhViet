import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/config.dart';
import '../widgets/check_flow_widgets.dart';

/// Hàm dựng khung quét QR. Tách ra để test thay bằng khung giả (camera thật không chạy trong test).
/// [onCode] được gọi với chuỗi đọc được; [onError] khi camera lỗi / bị từ chối quyền
/// (màn chấm công sẽ tự chuyển sang nhập mã tay).
typedef QrScannerBuilder = Widget Function(
  BuildContext context, {
  required void Function(String code) onCode,
  required void Function(String message) onError,
});

/// Khung quét QR thật dùng mobile_scanner (chỉ nhận mã QR).
Widget buildMobileScanner(
  BuildContext context, {
  required void Function(String code) onCode,
  required void Function(String message) onError,
}) =>
    _MobileScannerView(onCode: onCode, onError: onError);

class _MobileScannerView extends StatefulWidget {
  final void Function(String code) onCode;
  final void Function(String message) onError;

  const _MobileScannerView({required this.onCode, required this.onError});

  @override
  State<_MobileScannerView> createState() => _MobileScannerViewState();
}

class _MobileScannerViewState extends State<_MobileScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: AppConfig.qrUseFrontCamera ? CameraFacing.front : CameraFacing.back,
  );
  bool _errorReported = false;
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final value = b.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        if (mounted) setState(() => _detected = true);
        widget.onCode(value.trim());
        return;
      }
    }
  }

  String _messageFor(MobileScannerException e) => switch (e.errorCode) {
        MobileScannerErrorCode.permissionDenied => 'Bạn chưa cấp quyền camera cho ứng dụng.',
        MobileScannerErrorCode.unsupported => 'Thiết bị không hỗ trợ quét mã QR.',
        _ => 'Không mở được camera.',
      };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              if (!_errorReported) {
                _errorReported = true;
                // Báo lỗi sau frame này để màn cha chuyển sang nhập tay (không setState trong build)
                WidgetsBinding.instance.addPostFrameCallback((_) => widget.onError(_messageFor(error)));
              }
              return const ColoredBox(color: Colors.black, child: Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48)));
            },
          ),
          // Khung ngắm phủ trên camera (chỉ hiển thị, không bắt chạm)
          Positioned.fill(child: QrScanOverlay(detected: _detected)),
        ],
      ),
    );
  }
}
