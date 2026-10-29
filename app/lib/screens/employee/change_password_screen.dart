import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common_widgets.dart';

/// Nhân viên tự đổi mật khẩu (mật khẩu ban đầu do admin đặt).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final provider = context.read<ProfileProvider>();
    final ok = await guardAction(
      context,
      () => provider.changePassword(currentPassword: _current.text, newPassword: _new.text),
      success: 'Đổi mật khẩu thành công',
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PasswordField(
                key: const Key('cp_current'),
                controller: _current,
                label: 'Mật khẩu hiện tại',
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.required(v, 'Mật khẩu hiện tại'),
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('cp_new'),
                controller: _new,
                label: 'Mật khẩu mới',
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final base = Validators.password(v);
                  if (base != null) return base;
                  return v == _current.text ? 'Mật khẩu mới phải khác mật khẩu hiện tại' : null;
                },
              ),
              const SizedBox(height: 16),
              PasswordField(
                key: const Key('cp_confirm'),
                controller: _confirm,
                label: 'Nhập lại mật khẩu mới',
                enabled: !_busy,
                validator: (v) => v != _new.text ? 'Mật khẩu nhập lại không khớp' : null,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              BusyButton(key: const Key('cp_submit'), label: 'Đổi mật khẩu', busy: _busy, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
