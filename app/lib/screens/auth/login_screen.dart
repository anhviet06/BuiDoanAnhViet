import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

/// Đăng nhập bước 1: "Email hoặc tên đăng nhập" + mật khẩu -> server gửi OTP -> sang màn nhập OTP.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwFocus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearNotice();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = _idCtrl.text.trim();
      final pw = _pwCtrl.text;
      final challenge = await auth.login(id, pw);
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => OtpScreen(identifier: id, password: pw, challenge: challenge),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Đăng ký xong sẽ chuyển thẳng sang màn OTP (RegisterScreen tự thay thế chính nó)
  Future<void> _openRegister() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<AuthProvider>().notice;
    return AuthScaffold(
      title: 'Đăng nhập',
      subtitle: 'Chấm công nhân viên - an toàn với xác thực OTP',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (notice != null) ...[
              MessageBanner(message: notice, isError: false, icon: Icons.history_toggle_off_rounded),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              MessageBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const Key('login_id'),
              controller: _idCtrl,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email hoặc tên đăng nhập',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) => Validators.required(v, 'Email hoặc tên đăng nhập'),
              onFieldSubmitted: (_) => _pwFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            PasswordField(
              key: const Key('login_password'),
              controller: _pwCtrl,
              focusNode: _pwFocus,
              enabled: !_busy,
              validator: (v) => Validators.required(v, 'Mật khẩu'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            BusyButton(key: const Key('login_submit'), label: 'Đăng nhập', busy: _busy, onPressed: _submit),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Chưa có tài khoản?'),
                TextButton(
                  key: const Key('login_to_register'),
                  onPressed: _busy ? null : _openRegister,
                  child: const Text('Đăng ký'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
