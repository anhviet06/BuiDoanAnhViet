import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_widgets.dart';

/// Đăng nhập bước 2: nhập OTP. Thành công thì AuthProvider đổi trạng thái và AuthGate
/// tự đóng màn này, chuyển sang trang theo role.
/// [password] chỉ giữ trong bộ nhớ của màn này để "Gửi lại mã" (gọi lại bước 1).
class OtpScreen extends StatefulWidget {
  final String identifier;
  final String password;
  final LoginChallenge challenge;

  const OtpScreen({super.key, required this.identifier, required this.password, required this.challenge});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _cooldownSeconds = 30;

  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  Timer? _timer;
  int _cooldown = _cooldownSeconds;
  String? _devOtp;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _devOtp = widget.challenge.devOtp;
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await context.read<AuthProvider>().verifyOtp(widget.identifier, _otpCtrl.text);
      // Thành công: AuthGate sẽ đóng màn này và chuyển trang theo role
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        _otpCtrl.clear();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      final challenge = await context.read<AuthProvider>().login(widget.identifier, widget.password);
      if (!mounted) return;
      _otpCtrl.clear();
      setState(() {
        _devOtp = challenge.devOtp;
        _info = 'Đã gửi lại mã OTP.';
      });
      _startCooldown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không gửi lại được mã. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canResend = _cooldown <= 0 && !_resending && !_busy;
    return AuthScaffold(
      showBack: true,
      title: 'Nhập mã OTP',
      subtitle: 'Mã gồm 6 chữ số đã được gửi tới email của tài khoản ${widget.identifier}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_devOtp != null) ...[
              MessageBanner(
                key: const Key('otp_dev_banner'),
                message: 'Chế độ demo: OTP là $_devOtp',
                isError: false,
                icon: Icons.science_outlined,
                trailing: TextButton(
                  key: const Key('otp_fill'),
                  onPressed: _busy ? null : () => _otpCtrl.text = _devOtp!,
                  child: const Text('Tự điền'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[MessageBanner(message: _error!), const SizedBox(height: 16)],
            if (_info != null) ...[
              MessageBanner(message: _info!, isError: false, icon: Icons.mark_email_read_outlined),
              const SizedBox(height: 16),
            ],
            OtpBoxes(controller: _otpCtrl, focusNode: _otpFocus, enabled: !_busy, validator: Validators.otp, onSubmitted: (_) => _verify()),
            const SizedBox(height: 24),
            BusyButton(key: const Key('otp_submit'), label: 'Xác nhận', busy: _busy, onPressed: _verify),
            const SizedBox(height: 12),
            TextButton(
              key: const Key('otp_resend'),
              onPressed: canResend ? _resend : null,
              child: Text(
                _resending
                    ? 'Đang gửi lại...'
                    : _cooldown > 0
                    ? 'Gửi lại mã sau ${_cooldown}s'
                    : 'Gửi lại mã',
                style: TextStyle(color: canResend ? scheme.primary : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
