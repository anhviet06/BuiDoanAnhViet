import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../services/face_liveness.dart';
import 'auth_widgets.dart';
import 'face_widgets.dart';

/// Khung xác thực khuôn mặt thật (liveness) bằng camera TRƯỚC + ML Kit chạy trên máy (ảnh không gửi đi đâu).
/// Thử thách: thấy mặt bình thường -> 2 hành động ngẫu nhiên (cười / quay trái / quay phải).
/// Lỗi camera hoặc hết giờ thì hiện thông báo + nút Thử lại. Giải phóng camera khi rời màn.
Widget buildFaceLiveness(BuildContext context, {required VoidCallback onVerified}) => FaceLivenessView(onVerified: onVerified);

class FaceLivenessView extends StatefulWidget {
  final VoidCallback onVerified;

  const FaceLivenessView({super.key, required this.onVerified});

  @override
  State<FaceLivenessView> createState() => _FaceLivenessViewState();
}

class _FaceLivenessViewState extends State<FaceLivenessView> {
  final LivenessEngine _engine = LivenessEngine();
  CameraController? _controller;
  CameraDescription? _camera;
  FaceDetector? _detector;
  Timer? _timer;
  LivenessState? _state;
  String? _error;
  bool _starting = true;
  bool _processing = false;
  bool _disposed = false;
  bool _notified = false;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _disposed = true;
    _release();
    super.dispose();
  }

  void _release() {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    final detector = _detector;
    _controller = null;
    _detector = null;
    // Dừng stream rồi mới giải phóng camera (camera sau của bước QR đã được giải phóng trước đó)
    () async {
      try {
        if (controller != null && controller.value.isStreamingImages) await controller.stopImageStream();
      } catch (_) {}
      try {
        await controller?.dispose();
      } catch (_) {}
      try {
        await detector?.close();
      } catch (_) {}
    }();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
      _state = null;
      _notified = false;
    });
    try {
      // Chờ một chút để camera sau của bước quét QR được giải phóng hẳn
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (_disposed) return;
      final cameras = await availableCameras();
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      if (front.isEmpty) {
        throw _FaceCameraError('Thiết bị không có camera trước để xác thực khuôn mặt.');
      }
      _camera = front.first;
      final controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      _detector = FaceDetector(
        options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.fast, minFaceSize: 0.25),
      );
      _beginChallenge();
      setState(() => _starting = false);
    } on CameraException catch (e) {
      _fail(_cameraMessage(e));
    } on _FaceCameraError catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Không mở được camera. Vui lòng thử lại.');
    }
  }

  void _fail(String message) {
    _release();
    if (!mounted) return;
    setState(() {
      _starting = false;
      _error = message;
    });
  }

  String _cameraMessage(CameraException e) {
    final code = e.code;
    if (code == 'CameraAccessDenied' || code == 'CameraAccessDeniedWithoutPrompt' || code == 'CameraAccessRestricted') {
      return 'Bạn chưa cấp quyền camera cho ứng dụng. Hãy cấp quyền (Cài đặt > Ứng dụng > TimeGuard > Quyền) rồi thử lại.';
    }
    return 'Không mở được camera trước. Vui lòng thử lại.';
  }

  /// Bắt đầu (hoặc làm lại) thử thách với 2 hành động ngẫu nhiên mới.
  void _beginChallenge() {
    final controller = _controller;
    if (controller == null) return;
    _engine.start(DateTime.now());
    _notified = false;
    _state = _engine.state;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _apply(_engine.tick(DateTime.now())));
    if (!controller.value.isStreamingImages) controller.startImageStream(_onImage);
  }

  Future<void> _onImage(CameraImage image) async {
    if (_processing || _disposed || _detector == null) return;
    _processing = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final faces = await _detector!.processImage(input);
      if (_disposed) return;
      final obs = faces.length == 1
          ? FaceObservation(faceCount: 1, yaw: faces.first.headEulerAngleY, smile: faces.first.smilingProbability)
          : FaceObservation(faceCount: faces.length);
      _apply(_engine.update(obs, DateTime.now()));
    } catch (_) {
      // bỏ qua khung hình lỗi
    } finally {
      _processing = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;
    final sensor = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      compensation = camera.lensDirection == CameraLensDirection.front
          ? (sensor + compensation) % 360
          : (sensor - compensation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _apply(LivenessState state) {
    if (!mounted || _disposed) return;
    setState(() => _state = state);
    if (state.phase == LivenessPhase.failed) {
      _timer?.cancel();
      _controller?.stopImageStream().catchError((_) {});
    } else if (state.phase == LivenessPhase.success && !_notified) {
      _notified = true;
      _timer?.cancel();
      _controller?.stopImageStream().catchError((_) {});
      // Cho người dùng thấy dấu tick xanh rồi mới sang bước tiếp
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted && !_disposed) widget.onVerified();
      });
    }
  }

  void _retry() {
    final controller = _controller;
    if (_error != null || controller == null || !controller.value.isInitialized) {
      _start();
    } else {
      setState(_beginChallenge);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_rounded, size: 64, color: scheme.error),
          const SizedBox(height: 12),
          MessageBanner(key: const Key('face_error'), message: _error!, icon: Icons.videocam_off_rounded),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('face_retry'),
              onPressed: _start,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ),
        ],
      );
    }
    final controller = _controller;
    if (_starting || controller == null || !controller.value.isInitialized || _state == null) {
      return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
    }
    final state = _state!;
    final failed = state.phase == LivenessPhase.failed;
    final size = controller.value.previewSize ?? const Size(480, 640);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(width: size.shortestSide, height: size.longestSide, child: CameraPreview(controller)),
                  ),
                ),
                Positioned.fill(
                  child: FaceOvalOverlay(
                    tone: failed
                        ? FaceOvalTone.bad
                        : (state.faceOk ? FaceOvalTone.good : (state.hint.contains('nhiều hơn') ? FaceOvalTone.bad : FaceOvalTone.neutral)),
                    hint: state.hint,
                    secondsLeft: state.secondsLeft,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LivenessChecklist(
          progressKey: const Key('face_progress'),
          progress: state.progress,
          failed: failed,
          steps: ['Nhìn thẳng, mặt bình thường', for (final c in state.challenges) c.label],
          completedSteps: (state.neutralDone ? 1 : 0) + state.completed,
        ),
        if (failed) ...[
          const SizedBox(height: 10),
          MessageBanner(key: const Key('face_failed'), message: state.failureReason ?? 'Xác thực khuôn mặt không thành công.'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('face_retry'),
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ),
        ],
      ],
    );
  }
}

class _FaceCameraError implements Exception {
  final String message;

  _FaceCameraError(this.message);
}
