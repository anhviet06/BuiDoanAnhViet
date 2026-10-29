import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/app_user.dart';
import '../../providers/admin_providers.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common_widgets.dart';

/// Form thêm / sửa nhân viên. [user] = null là thêm mới (admin nhập mật khẩu ban đầu).
class UserFormScreen extends StatefulWidget {
  final AppUser? user;

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.user?.fullName);
  late final TextEditingController _email = TextEditingController(text: widget.user?.email);
  late final TextEditingController _username = TextEditingController(text: widget.user?.username);
  late final TextEditingController _rate =
      TextEditingController(text: widget.user == null ? '30000' : widget.user!.hourlyRate.round().toString());
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'employee';
  bool _busy = false;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _username.dispose();
    _rate.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final provider = context.read<UsersProvider>();
    final rate = double.parse(_rate.text.trim().isEmpty ? '0' : _rate.text.trim());
    final ok = await guardAction(
      context,
      () => _isEdit
          ? provider.update(widget.user!.id,
              email: _email.text.trim(),
              username: _username.text.trim(),
              fullName: _name.text.trim(),
              hourlyRate: rate,
              role: _role)
          : provider.create(
              email: _email.text.trim(),
              username: _username.text.trim(),
              password: _password.text,
              fullName: _name.text.trim(),
              hourlyRate: rate,
              role: _role),
      success: _isEdit ? 'Đã lưu thay đổi' : 'Đã thêm nhân viên',
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
    final isSelf = _isEdit && widget.user!.id == context.read<AuthProvider>().session?.userId;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa nhân viên' : 'Thêm nhân viên')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                key: const Key('uf_name'),
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => Validators.required(v, 'Họ và tên'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('uf_email'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                validator: Validators.email,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('uf_username'),
                controller: _username,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: (v) {
                  final empty = Validators.required(v, 'Tên đăng nhập');
                  return empty ?? Validators.optionalUsername(v);
                },
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 16),
                PasswordField(
                  key: const Key('uf_password'),
                  controller: _password,
                  label: 'Mật khẩu ban đầu',
                  enabled: !_busy,
                  textInputAction: TextInputAction.next,
                  validator: Validators.password,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text('Nhân viên có thể tự đổi mật khẩu sau khi đăng nhập.',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('uf_rate'),
                controller: _rate,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Lương theo giờ (₫)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) => Validators.required(v, 'Lương theo giờ'),
              ),
              const SizedBox(height: 20),
              Text('Vai trò', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const Key('uf_role'),
                segments: const [
                  ButtonSegment(value: 'employee', label: Text('Nhân viên'), icon: Icon(Icons.person_rounded)),
                  ButtonSegment(value: 'admin', label: Text('Quản trị'), icon: Icon(Icons.admin_panel_settings_rounded)),
                ],
                selected: {_role},
                onSelectionChanged: (_busy || isSelf) ? null : (s) => setState(() => _role = s.first),
              ),
              if (isSelf)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Bạn không thể tự đổi vai trò của chính mình.', style: Theme.of(context).textTheme.bodySmall),
                ),
              const SizedBox(height: 28),
              BusyButton(
                key: const Key('uf_submit'),
                label: _isEdit ? 'Lưu thay đổi' : 'Thêm nhân viên',
                busy: _busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
