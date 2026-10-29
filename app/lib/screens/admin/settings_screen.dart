import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/company_settings.dart';
import '../../providers/admin_providers.dart';
import '../../services/location_service.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';

/// Tab Cấu hình: vị trí công ty (nhập tay hoặc "Lấy vị trí hiện tại"), bán kính, mức phạt đi trễ.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CompanySettingsProvider>();
    if (p.loading && p.settings == null) return const LoadingView();
    if (p.settings == null) {
      return ErrorView(message: p.error ?? 'Không tải được cấu hình.', onRetry: p.load);
    }
    // key theo giá trị để form dựng lại khi dữ liệu mới về
    return _SettingsForm(settings: p.settings!);
  }
}

class _SettingsForm extends StatefulWidget {
  final CompanySettings settings;

  const _SettingsForm({required this.settings});

  @override
  State<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends State<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lat = TextEditingController(text: _fmt(widget.settings.latitude));
  late final TextEditingController _lng = TextEditingController(text: _fmt(widget.settings.longitude));
  late final TextEditingController _radius = TextEditingController(text: _fmt(widget.settings.radiusMeters));
  late final TextEditingController _penalty = TextEditingController(text: _fmt(widget.settings.latePenaltyPerMinute));
  bool _busy = false;
  bool _locating = false;
  String? _locError;

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  static double? _parse(String? v) => double.tryParse((v ?? '').trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    _penalty.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final pos = await context.read<LocationService>().current();
      if (!mounted) return;
      setState(() {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lng.text = pos.longitude.toStringAsFixed(6);
      });
      showAppSnack(context, 'Đã lấy vị trí hiện tại. Nhớ bấm Lưu cấu hình.');
    } on LocationException catch (e) {
      if (mounted) setState(() => _locError = e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String? _range(String? v, String field, double min, double max) {
    final n = _parse(v);
    if (n == null) return '$field không hợp lệ';
    return (n < min || n > max) ? '$field phải từ $min đến $max' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final value = CompanySettings(
      latitude: _parse(_lat.text)!,
      longitude: _parse(_lng.text)!,
      radiusMeters: _parse(_radius.text)!,
      latePenaltyPerMinute: _parse(_penalty.text)!,
    );
    await guardAction(context, () => context.read<CompanySettingsProvider>().save(value), success: 'Đã lưu cấu hình');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true, signed: true);
    final numberFilter = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'));
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Vị trí công ty', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Nhân viên chỉ chấm công được khi ở trong bán kính quanh vị trí này.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  key: const Key('set_lat'),
                  controller: _lat,
                  enabled: !_busy,
                  keyboardType: numberKeyboard,
                  inputFormatters: [numberFilter],
                  decoration: const InputDecoration(labelText: 'Vĩ độ'),
                  validator: (v) => _range(v, 'Vĩ độ', -90, 90),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  key: const Key('set_lng'),
                  controller: _lng,
                  enabled: !_busy,
                  keyboardType: numberKeyboard,
                  inputFormatters: [numberFilter],
                  decoration: const InputDecoration(labelText: 'Kinh độ'),
                  validator: (v) => _range(v, 'Kinh độ', -180, 180),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('set_locate'),
              onPressed: (_busy || _locating) ? null : _useCurrentLocation,
              icon: _locating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
              label: Text(_locating ? 'Đang lấy vị trí...' : 'Lấy vị trí hiện tại'),
            ),
          ),
          if (_locError != null) ...[const SizedBox(height: 12), MessageBanner(message: _locError!)],
          const SizedBox(height: 24),
          TextFormField(
            key: const Key('set_radius'),
            controller: _radius,
            enabled: !_busy,
            keyboardType: numberKeyboard,
            inputFormatters: [numberFilter],
            decoration: const InputDecoration(labelText: 'Bán kính cho phép (mét)', prefixIcon: Icon(Icons.radar_rounded)),
            validator: (v) => _range(v, 'Bán kính', 1, 100000),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('set_penalty'),
            controller: _penalty,
            enabled: !_busy,
            keyboardType: numberKeyboard,
            inputFormatters: [numberFilter],
            decoration: const InputDecoration(
              labelText: 'Phạt đi trễ (₫ / phút)',
              helperText: 'Nhân với số phút trễ tính từ giờ bắt đầu ca (khi quá thời gian ân hạn)',
              prefixIcon: Icon(Icons.gavel_rounded),
            ),
            validator: (v) => _range(v, 'Mức phạt', 0, 100000000),
          ),
          const SizedBox(height: 28),
          BusyButton(key: const Key('set_save'), label: 'Lưu cấu hình', busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
