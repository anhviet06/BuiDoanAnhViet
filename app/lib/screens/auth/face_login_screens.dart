import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/face_login_provider.dart';
import '../../services/face_liveness.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/state_views.dart';

/// Màn "Bật đăng nhập bằng khuôn mặt": xác nhận người sống rồi xin token thiết bị và lưu trên máy.
/// KHÔNG có nút "Bỏ qua". Trả true nếu bật thành công.
class FaceEnableScreen extends StatefulWidget {
  const FaceEnableScreen({super.key});

  @override
  State<FaceEnableScreen> createState() => _FaceEnableScreenState();
}

class _FaceEnableScreenState extends State<FaceEnableScreen> {
  bool _verified = false;
  bool _busy = false;
  String? _error;

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final provider = context.read<FaceLoginProvider>();
    final navigator = Navigator.of(context);
    String? error;
    try {
      await provider.enable();
    } catch (_) {
      error = 'Không bật được đăng nhập bằng khuôn mặt. Kiểm tra kết nối rồi thử lại.';
    }
    if (!mounted) return;
    if (error == null) {
      showAppSnack(context, 'Đã bật đăng nhập bằng khuôn mặt');
      navigator.pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Bật đăng nhập bằng khuôn mặt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Làm theo hướng dẫn để xác nhận bạn là người thật. Lần sau bạn đăng nhập chỉ cần quét khuôn mặt.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Ứng dụng chỉ xác nhận người sống trên máy này, không nhận diện danh tính. Ảnh không được gửi đi đâu.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (!_verified)
              context.read<FaceLivenessBuilder>()(context, onVerified: () {
                setState(() => _verified = true);
                _enable();
              })
            else if (_busy)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else ...[
              MessageBanner(key: const Key('face_enable_error'), message: _error ?? 'Không bật được. Vui lòng thử lại.'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('face_enable_retry'),
                  onPressed: _enable,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Màn đăng nhập bằng khuôn mặt: xác nhận người sống rồi đăng nhập bằng token thiết bị.
/// Thất bại 3 lần (hết giờ) -> quay về với thông báo để dùng mật khẩu + OTP. Không có nút "Bỏ qua".
/// Pop trả về thông báo lỗi (String) nếu cần hiện ở màn đăng nhập, hoặc null.
class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen> {
  int _failures = 0;
  bool _verified = false;
  bool _busy = false;
  String? _error;

  void _onFailed() {
    _failures++;
    if (_failures >= FaceLoginProvider.maxFailures) {
      Navigator.of(context).pop('Xác thực khuôn mặt thất bại ${FaceLoginProvider.maxFailures} lần. Hãy đăng nhập bằng mật khẩu và OTP.');
    } else {
      setState(() {});
    }
  }

  Future<void> _login() async {
    setState(() {
      _verified = true;
      _busy = true;
      _error = null;
    });
    final provider = context.read<FaceLoginProvider>();
    final navigator = Navigator.of(context);
    final error = await provider.loginWithFace();
    if (!mounted) return;
    if (error == null) return; // đăng nhập xong: AuthGate tự đóng các màn con
    if (!provider.enabled) {
      navigator.pop(error); // hồ sơ đã bị xóa (token hết hạn/thu hồi): về đăng nhập mật khẩu kèm thông báo
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập bằng khuôn mặt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Nhìn thẳng vào camera và làm theo hướng dẫn để xác nhận bạn là người thật.', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Lần thử ${(_failures + 1).clamp(1, FaceLoginProvider.maxFailures)}/${FaceLoginProvider.maxFailures}', key: const Key('face_login_attempt'), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            if (!_verified)
              context.read<FaceLivenessBuilder>()(context, onVerified: _login, onFailed: _onFailed)
            else if (_busy)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else ...[
              MessageBanner(key: const Key('face_login_error'), message: _error ?? 'Không đăng nhập được. Vui lòng thử lại.'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('face_login_retry'),
                  onPressed: _login,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const Key('face_login_use_password'),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Dùng mật khẩu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
