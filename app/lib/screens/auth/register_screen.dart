import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_screen.dart';

/// Đăng ký tài khoản nhân viên (role employee do server gán). Thành công thì server gửi OTP tới email
/// và app chuyển sang màn OTP; xác thực xong mới vào app.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _emailCtrl.text.trim();
      final password = _pwCtrl.text;
      final challenge = await context.read<AuthProvider>().register(
            email: email,
            password: password,
            fullName: _nameCtrl.text.trim(),
            username: _usernameCtrl.text.trim(),
          );
      if (!mounted) return;
      // Xác thực email bằng OTP: thay màn đăng ký bằng màn OTP; verify xong AuthGate tự vào app
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => OtpScreen(identifier: email, password: password, challenge: challenge),
      ));
      return;
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Tạo tài khoản',
      subtitle: 'Đăng ký bằng email, mã OTP xác thực sẽ được gửi tới email đó',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              MessageBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const Key('reg_name'),
              controller: _nameCtrl,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => Validators.required(v, 'Họ và tên'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('reg_email'),
              controller: _emailCtrl,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('reg_username'),
              controller: _usernameCtrl,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên đăng nhập (tùy chọn)',
                helperText: 'Bỏ trống sẽ lấy phần trước dấu @ của email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: Validators.optionalUsername,
            ),
            const SizedBox(height: 16),
            PasswordField(
              key: const Key('reg_password'),
              controller: _pwCtrl,
              enabled: !_busy,
              textInputAction: TextInputAction.next,
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            PasswordField(
              key: const Key('reg_confirm'),
              controller: _confirmCtrl,
              label: 'Nhập lại mật khẩu',
              enabled: !_busy,
              validator: (v) => v != _pwCtrl.text ? 'Mật khẩu nhập lại không khớp' : null,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            BusyButton(key: const Key('reg_submit'), label: 'Đăng ký', busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
