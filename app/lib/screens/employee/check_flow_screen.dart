import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/attendance.dart';
import '../../models/check_request.dart';
import '../../providers/check_flow_controller.dart';
import '../../providers/employee_providers.dart';
import '../../services/device_id_service.dart';
import '../../services/face_liveness.dart';
import '../../services/employee_services.dart';
import '../../services/location_service.dart';
import '../../services/qr_scanner.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/check_flow_widgets.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui_kit.dart';

/// Màn chấm công nhiều bước: 1 Quét QR (hoặc nhập mã tay) -> 2 Vị trí (GPS) -> 3 Xác thực khuôn mặt (liveness) -> kết quả.
/// Tự xác định check-in hay check-out theo trạng thái hôm nay; nhiều ca thì cho chọn ca trước.
class CheckFlowScreen extends StatelessWidget {
  /// Có thì chọn sẵn ca này (nút "Check-out ca này" ở thẻ ca); không có thì tự chọn khi chỉ có 1 ca, ngược lại hiện danh sách.
  final int? shiftId;

  const CheckFlowScreen({super.key, this.shiftId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) {
        final controller = CheckFlowController(
          location: c.read<LocationService>(),
          device: c.read<DeviceIdService>(),
          attendance: c.read<AttendanceService>(),
        );
        // Chỉ có một ca chấm được thì bắt đầu ngay; nhiều ca thì hiện danh sách chọn
        final items = c.read<TodayProvider>().info?.items ?? const <TodayItem>[];
        final preset = shiftId == null ? null : items.where((i) => i.shift.id == shiftId).firstOrNull;
        if (preset != null && actionFor(preset) != CheckAction.done) {
          controller.choose(preset);
        } else {
          controller.start(items);
        }
        return controller;
      },
      child: const _FlowView(),
    );
  }
}

class _FlowView extends StatelessWidget {
  const _FlowView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CheckFlowController>();
    final today = context.watch<TodayProvider>().info;
    final onLeave = today?.onLeave ?? false;
    final options = CheckFlowController.actionable(today?.items ?? const []);

    return Scaffold(
      appBar: AppBar(title: Text(c.selected == null ? 'Chấm công' : (c.isCheckOut ? 'Chấm công ra ca' : 'Chấm công vào ca'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.step != FlowStep.selectShift && c.step != FlowStep.result) ...[_StepBar(step: c.step), const SizedBox(height: 16)],
              Expanded(child: _body(context, c, options, onLeave)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CheckFlowController c, List<TodayItem> options, bool onLeave) {
    switch (c.step) {
      case FlowStep.selectShift:
        return _ShiftChooser(options: options, onLeave: onLeave, open: context.read<TodayProvider>().info?.openInHours, onPick: c.choose);
      case FlowStep.location:
        return _LocationStep(controller: c);
      case FlowStep.qr:
        return _QrStep(controller: c);
      case FlowStep.face:
        return _FaceStep(controller: c);
      case FlowStep.submitting:
        return const LoadingView(message: 'Đang gửi dữ liệu chấm công...');
      case FlowStep.result:
        return _ResultStep(controller: c);
    }
  }
}

/// Thanh tiến trình 3 bước.
class _StepBar extends StatelessWidget {
  final FlowStep step;

  const _StepBar({required this.step});

  @override
  Widget build(BuildContext context) {
    final current = switch (step) {
      FlowStep.qr => 0,
      FlowStep.location => 1,
      _ => 2,
    };
    return StepperBar(
      current: current,
      labels: const ['Quét QR', 'Vị trí', 'Khuôn mặt'],
      icons: const [Icons.qr_code_scanner_rounded, Icons.my_location_rounded, Icons.face_retouching_natural_rounded],
    );
  }
}

class _ShiftChooser extends StatelessWidget {
  final List<TodayItem> options;
  final bool onLeave;
  final TodayItem? open; // ca đang mở còn trong giờ: các ca khác bị khóa
  final void Function(TodayItem) onPick;

  const _ShiftChooser({required this.options, required this.onLeave, required this.onPick, this.open});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (options.isEmpty) {
      return const EmptyView(
        icon: Icons.task_alt_rounded,
        title: 'Không có ca nào cần chấm công',
        subtitle: 'Bạn đã hoàn thành các ca hôm nay hoặc hôm nay chưa có ca làm việc.',
      );
    }
    return ListView(
      children: [
        Text('Chọn ca cần chấm công', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Hãy quét đúng mã QR của ca bạn chọn.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (onLeave) ...[
          const SizedBox(height: 12),
          const MessageBanner(
            message: 'Hôm nay bạn có đơn nghỉ phép đã duyệt: chỉ chấm công ra ca được, vào ca sẽ bị từ chối.',
            isError: false,
          ),
        ],
        const SizedBox(height: 16),
        for (final item in options) ...[
          Builder(builder: (context) {
            final blocked = CheckFlowController.isBlocked(item, open);
            final action = actionFor(item) == CheckAction.checkOut ? 'Chấm công RA ca' : 'Chấm công VÀO ca';
            return Opacity(
              opacity: blocked ? 0.5 : 1,
              child: Card(
                child: ListTile(
                  key: Key('flow_pick_${item.shift.id}'),
                  enabled: !blocked,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      blocked ? Icons.lock_outline_rounded : (actionFor(item) == CheckAction.checkOut ? Icons.logout_rounded : Icons.login_rounded),
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(item.shift.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(blocked ? '${item.shift.rangeLabel} · Đang trong ${open!.shift.name} chưa check-out' : '${item.shift.rangeLabel} · $action'),
                  trailing: blocked ? null : const Icon(Icons.chevron_right_rounded),
                  onTap: blocked ? null : () => onPick(item),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LocationStep extends StatelessWidget {
  final CheckFlowController controller;

  const _LocationStep({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: GpsStatusCard(
          loading: controller.busy,
          errorMessage: controller.error,
          onRetry: controller.runLocation,
          retryKey: const Key('flow_location_retry'),
        ),
      ),
    );
  }
}

class _QrStep extends StatefulWidget {
  final CheckFlowController controller;

  const _QrStep({required this.controller});

  @override
  State<_QrStep> createState() => _QrStepState();
}

class _QrStepState extends State<_QrStep> {
  final _manual = TextEditingController();
  bool _manualMode = false;
  String? _scannerError;

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  void _onScannerError(String message) {
    // Camera lỗi / bị từ chối quyền: tự chuyển sang nhập mã tay
    if (!mounted) return;
    setState(() {
      _scannerError = message;
      _manualMode = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListView(
      children: [
        Text(_manualMode ? 'Nhập mã ca' : 'Quét mã QR của ca', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          _manualMode ? 'Nhập mã do quản trị viên cung cấp (hiển thị dưới mã QR của ca).' : 'Đưa camera vào mã QR đặt tại nơi làm việc.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (_scannerError != null) ...[
          MessageBanner(key: const Key('flow_scanner_error'), message: '$_scannerError Hãy nhập mã tay.', icon: Icons.videocam_off_rounded),
          const SizedBox(height: 16),
        ],
        if (!_manualMode)
          AspectRatio(
            aspectRatio: 1,
            child: context.read<QrScannerBuilder>()(context, onCode: c.onQr, onError: _onScannerError),
          )
        else ...[
          TextField(
            key: const Key('flow_manual_field'),
            controller: _manual,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: c.onQr,
            decoration: const InputDecoration(labelText: 'Mã ca', prefixIcon: Icon(Icons.pin_outlined)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(key: const Key('flow_manual_submit'), onPressed: () => c.onQr(_manual.text), child: const Text('Tiếp tục')),
          ),
        ],
        const SizedBox(height: 12),
        TextButton.icon(
          key: const Key('flow_toggle_manual'),
          onPressed: () => setState(() {
            _manualMode = !_manualMode;
            if (!_manualMode) _scannerError = null;
          }),
          icon: Icon(_manualMode ? Icons.qr_code_scanner_rounded : Icons.keyboard_rounded),
          label: Text(_manualMode ? 'Quét bằng camera' : 'Nhập mã tay'),
        ),
      ],
    );
  }
}

class _FaceStep extends StatelessWidget {
  final CheckFlowController controller;

  const _FaceStep({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final pos = controller.position;
    return ListView(
      children: [
        if (pos != null && pos.isMocked) ...[
          const MessageBanner(
            key: Key('flow_mock_warning'),
            message: 'Thiết bị báo vị trí GIẢ (mock location). Lần chấm công này sẽ bị đánh dấu nghi ngờ.',
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 12),
        ],
        if (pos != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: StatusColors.of(context, 'approved')),
                const SizedBox(width: 6),
                Text('Đã lấy vị trí (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})', style: text.bodySmall),
              ],
            ),
          ),
        Text('Xác thực khuôn mặt', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Nhìn thẳng vào camera trước rồi làm theo hướng dẫn. Ảnh chỉ xử lý trên máy, không gửi đi đâu.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        context.read<FaceLivenessBuilder>()(context, onVerified: () => controller.onFace(verified: true)),
        if (AppConfig.allowSkipFace) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('face_skip'),
            onPressed: () => controller.onFace(verified: false),
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('Bỏ qua (chỉ để demo)'),
          ),
        ],
      ],
    );
  }
}

class _ResultStep extends StatelessWidget {
  final CheckFlowController controller;

  const _ResultStep({required this.controller});

  @override
  Widget build(BuildContext context) {
    final ok = controller.success;
    if (ok == null) return _Failure(controller: controller);
    return _Success(result: ok, isCheckOut: controller.isCheckOut);
  }
}

class _Success extends StatelessWidget {
  final CheckResult result;
  final bool isCheckOut;

  const _Success({required this.result, required this.isCheckOut});

  @override
  Widget build(BuildContext context) {
    final Attendance a = result.attendance;
    final faceOk = isCheckOut ? (a.checkOutFaceVerified ?? false) : a.faceVerified;
    final tone = a.status == 'on-time' ? ReceiptTone.success : ReceiptTone.warning;
    return ListView(
      key: const Key('flow_success'),
      children: [
        CheckResultReceipt(
          tone: tone,
          title: isCheckOut ? 'Đã chấm công ra ca' : 'Đã chấm công vào ca',
          message: result.message,
          rows: [
            ReceiptRow(label: 'Ca', value: a.shiftName ?? ''),
            ReceiptRow(label: 'Trạng thái', valueWidget: Pill(label: StatusColors.label(a.status), color: StatusColors.of(context, a.status))),
            ReceiptRow(label: isCheckOut ? 'Giờ ra' : 'Giờ vào', value: Fmt.time(isCheckOut && a.checkOutAt != null ? a.checkOutAt! : a.checkInAt)),
            ReceiptRow(label: 'Cách công ty', value: '${a.distanceMeters.round()} m'),
            ReceiptRow(
              label: 'Khuôn mặt',
              valueWidget: faceOk
                  ? Pill(label: 'Đã xác thực khuôn mặt', color: StatusColors.of(context, 'on-time'), icon: Icons.verified_user_rounded)
                  : Pill(label: 'Chưa xác thực mặt', color: Theme.of(context).colorScheme.outline, icon: Icons.person_off_outlined),
            ),
            if (a.lateMinutes > 0) ReceiptRow(label: 'Đi trễ', value: '${a.lateMinutes} phút (phạt ${Fmt.money(a.latePenalty)})'),
            if (isCheckOut) ...[
              ReceiptRow(label: 'Số giờ làm', value: Fmt.hours(a.workedHours)),
              ReceiptRow(label: 'Lương ca', value: Fmt.money(a.pay)),
            ],
            if (a.isSuspicious && a.suspiciousReason != null) ReceiptRow(label: 'Cảnh báo', value: a.suspiciousReason!),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('flow_done'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xong'),
          ),
        ),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  final CheckFlowController controller;

  const _Failure({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        key: const Key('flow_failure'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckResultReceipt(
              tone: ReceiptTone.danger,
              title: 'Chấm công không thành công',
              message: controller.failure ?? '',
              dangerReason: controller.failure ?? '',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('flow_retry'),
                onPressed: controller.retryAfterFailure,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('flow_close'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
