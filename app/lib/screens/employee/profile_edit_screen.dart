import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/common_widgets.dart';

/// Quy tắc kiểm tra hồ sơ phía app (server vẫn kiểm tra lại).
class ProfileValidators {
  static final RegExp _mobile = RegExp(r'^0[35789]\d{8}$');

  /// Chuẩn hóa SĐT về 0xxxxxxxxx; null nếu không hợp lệ.
  static String? normalizePhone(String input) {
    var s = input.trim().replaceAll(RegExp(r'[\s.\-()]'), '');
    if (s.startsWith('+84')) {
      s = '0${s.substring(3)}';
    } else if (s.startsWith('84') && s.length == 11) {
      s = '0${s.substring(2)}';
    }
    return _mobile.hasMatch(s) ? s : null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return null; // tùy chọn
    return normalizePhone(v) == null ? 'Số điện thoại không hợp lệ (ví dụ 0912345678)' : null;
  }

  static String? address(String? v) => (v != null && v.trim().length > 200) ? 'Địa chỉ tối đa 200 ký tự' : null;

  static String? fullName(String? v) => (v == null || v.trim().isEmpty) ? 'Họ và tên không được để trống' : null;
}

/// Màn "Sửa hồ sơ": họ tên, số điện thoại, ngày sinh, địa chỉ (đều có thể để trống trừ họ tên).
class ProfileEditScreen extends StatefulWidget {
  final AppUser user;

  const ProfileEditScreen({super.key, required this.user});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.user.fullName);
  late final TextEditingController _phone = TextEditingController(text: widget.user.phone ?? '');
  late final TextEditingController _address = TextEditingController(text: widget.user.address ?? '');
  late DateTime? _dob = widget.user.dateOfBirth;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Chọn ngày sinh',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final profile = context.read<ProfileProvider>();
    final auth = context.read<AuthProvider>();
    final name = _name.text.trim();
    final navigator = Navigator.of(context);
    final ok = await guardAction(
      context,
      () => profile.updateProfile(
        fullName: name,
        phone: _phone.text.trim().isEmpty ? '' : ProfileValidators.normalizePhone(_phone.text)!,
        dateOfBirth: _dob == null ? '' : _isoDay(_dob!),
        address: _address.text.trim(),
      ),
      success: 'Đã cập nhật hồ sơ',
    );
    if (!mounted) return;
    if (ok) {
      await auth.updateFullName(name);
      navigator.pop();
    } else {
      setState(() => _busy = false);
    }
  }

  static String _isoDay(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa hồ sơ')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                key: const Key('pe_name'),
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.badge_outlined)),
                validator: ProfileValidators.fullName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('pe_phone'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại', hintText: '0912345678', prefixIcon: Icon(Icons.phone_outlined)),
                validator: ProfileValidators.phone,
              ),
              const SizedBox(height: 16),
              InkWell(
                key: const Key('pe_dob'),
                borderRadius: BorderRadius.circular(14),
                onTap: _busy ? null : _pickDob,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Ngày sinh',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    suffixIcon: _dob == null
                        ? null
                        : IconButton(
                            key: const Key('pe_dob_clear'),
                            tooltip: 'Xóa ngày sinh',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: _busy ? null : () => setState(() => _dob = null),
                          ),
                  ),
                  child: Text(_dob == null ? 'Chưa nhập' : Fmt.date(_dob!), style: TextStyle(color: _dob == null ? scheme.onSurfaceVariant : null)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('pe_address'),
                controller: _address,
                enabled: !_busy,
                maxLines: 2,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Địa chỉ', prefixIcon: Icon(Icons.home_outlined)),
                validator: ProfileValidators.address,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('pe_save'),
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : const Text('Lưu hồ sơ'),
                ),
              ),
              const SizedBox(height: 12),
              Text('Email và tên đăng nhập không đổi được ở đây.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
