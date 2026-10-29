import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../models/shift.dart';
import '../../providers/admin_providers.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common_widgets.dart';

/// Form thêm / sửa ca làm việc. [shift] = null là thêm mới.
class ShiftFormScreen extends StatefulWidget {
  final Shift? shift;

  const ShiftFormScreen({super.key, this.shift});

  @override
  State<ShiftFormScreen> createState() => _ShiftFormScreenState();
}

class _ShiftFormScreenState extends State<ShiftFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.shift?.name);
  late final TextEditingController _grace =
      TextEditingController(text: (widget.shift?.lateGraceMinutes ?? 5).toString());
  late TimeOfDay _start = widget.shift?.start ?? const TimeOfDay(hour: 8, minute: 0);
  late TimeOfDay _end = widget.shift?.end ?? const TimeOfDay(hour: 17, minute: 0);
  late bool _endOfDay = widget.shift?.endsAtMidnight ?? false; // giờ kết thúc 24:00 (không chọn được bằng bộ chọn giờ)
  late bool _active = widget.shift?.isActive ?? true;
  String? _timeError;
  bool _busy = false;

  bool get _isEdit => widget.shift != null;

  @override
  void dispose() {
    _name.dispose();
    _grace.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      helpText: isStart ? 'Giờ bắt đầu ca' : 'Giờ kết thúc ca',
      builder: (ctx, child) =>
          MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
        _endOfDay = false;
      }
      _timeError = null;
    });
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    final startMin = _start.hour * 60 + _start.minute;
    final endMin = _end.hour * 60 + _end.minute;
    if (!_endOfDay && endMin <= startMin) {
      setState(() => _timeError = 'Giờ kết thúc phải sau giờ bắt đầu');
      return;
    }
    if (!formOk) return;

    setState(() => _busy = true);
    final provider = context.read<ShiftsProvider>();
    final name = _name.text.trim();
    final grace = int.parse(_grace.text.trim());
    final start = Shift.format(_start);
    final end = _endOfDay ? '24:00' : Shift.format(_end);
    final ok = await guardAction(
      context,
      () => _isEdit
          ? provider.update(widget.shift!.id,
              name: name, startTime: start, endTime: end, lateGraceMinutes: grace, isActive: _active)
          : provider.create(name: name, startTime: start, endTime: end, lateGraceMinutes: grace, isActive: _active),
      success: _isEdit ? 'Đã lưu ca làm việc' : 'Đã thêm ca làm việc',
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa ca làm việc' : 'Thêm ca làm việc')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                key: const Key('sf_name'),
                controller: _name,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Tên ca', prefixIcon: Icon(Icons.label_outline_rounded)),
                validator: (v) => Validators.required(v, 'Tên ca'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _TimeTile(key: const Key('sf_start'), label: 'Bắt đầu', time: _start, onTap: _busy ? null : () => _pick(true))),
                  const SizedBox(width: 12),
                  Expanded(child: _TimeTile(key: const Key('sf_end'), label: 'Kết thúc', time: _end, display: _endOfDay ? '24:00' : null, onTap: _busy ? null : () => _pick(false))),
                ],
              ),
              if (_timeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 12),
                  child: Text(_timeError!, style: TextStyle(color: scheme.error, fontSize: 12)),
                ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('sf_grace'),
                controller: _grace,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Thời gian ân hạn (phút)',
                  helperText: 'Đến trễ trong khoảng này vẫn tính đúng giờ',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                validator: (v) {
                  final empty = Validators.required(v, 'Thời gian ân hạn');
                  if (empty != null) return empty;
                  return int.parse(v!.trim()) > 240 ? 'Tối đa 240 phút' : null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('sf_active'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Đang hoạt động'),
                subtitle: const Text('Tắt để nhân viên không chấm công ca này được'),
                value: _active,
                onChanged: _busy ? null : (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 20),
              BusyButton(
                key: const Key('sf_submit'),
                label: _isEdit ? 'Lưu thay đổi' : 'Thêm ca',
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

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final String? display;
  final VoidCallback? onTap;

  const _TimeTile({super.key, required this.label, required this.time, this.display, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(display ?? Shift.format(time), style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
