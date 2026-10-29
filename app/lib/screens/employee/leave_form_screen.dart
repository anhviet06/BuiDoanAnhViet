import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/validators.dart';
import '../../models/leave_request.dart';
import '../../providers/employee_providers.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common_widgets.dart';

/// Tạo / sửa đơn nghỉ phép. [leave] = null là tạo mới. Chọn khoảng ngày bằng lịch.
class LeaveFormScreen extends StatefulWidget {
  final LeaveRequest? leave;

  /// Chỉ dùng cho test: ngày "hôm nay" để chặn chọn ngày quá khứ.
  final DateTime? today;

  const LeaveFormScreen({super.key, this.leave, this.today});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reason = TextEditingController(text: widget.leave?.reason);
  late DateTimeRange? _range = widget.leave == null
      ? null
      : DateTimeRange(start: widget.leave!.fromDate, end: widget.leave!.toDate);
  String? _rangeError;
  bool _busy = false;

  bool get _isEdit => widget.leave != null;

  DateTime get _today {
    final n = widget.today ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 365)),
      initialDateRange: _range,
      helpText: 'Chọn ngày nghỉ',
      saveText: 'Chọn',
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _rangeError = null;
      });
    }
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    if (_range == null) {
      setState(() => _rangeError = 'Vui lòng chọn ngày nghỉ');
      return;
    }
    if (!formOk) return;

    setState(() => _busy = true);
    final provider = context.read<MyLeavesProvider>();
    final ok = await guardAction(
      context,
      () => _isEdit
          ? provider.update(widget.leave!.id, from: _range!.start, to: _range!.end, reason: _reason.text.trim())
          : provider.create(from: _range!.start, to: _range!.end, reason: _reason.text.trim()),
      success: _isEdit ? 'Đã cập nhật đơn nghỉ phép' : 'Đã gửi đơn nghỉ phép',
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
    final days = _range == null ? 0 : _range!.end.difference(_range!.start).inDays + 1;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Sửa đơn nghỉ phép' : 'Tạo đơn nghỉ phép')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              InkWell(
                key: const Key('lf_range'),
                borderRadius: BorderRadius.circular(14),
                onTap: _busy ? null : _pickRange,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: _rangeError != null ? Border.all(color: scheme.error) : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.date_range_rounded, color: scheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ngày nghỉ', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(
                              _range == null
                                  ? 'Bấm để chọn ngày'
                                  : '${Fmt.date(_range!.start)} - ${Fmt.date(_range!.end)}  ($days ngày)',
                              key: const Key('lf_range_text'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_rangeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(_rangeError!, style: TextStyle(color: scheme.error, fontSize: 12)),
                ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('lf_reason'),
                controller: _reason,
                enabled: !_busy,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Lý do nghỉ', alignLabelWithHint: true),
                validator: (v) => Validators.required(v, 'Lý do'),
              ),
              const SizedBox(height: 24),
              BusyButton(
                key: const Key('lf_submit'),
                label: _isEdit ? 'Lưu thay đổi' : 'Gửi đơn',
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
