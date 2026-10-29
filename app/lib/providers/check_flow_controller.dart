import 'package:flutter/foundation.dart';

import '../models/attendance.dart';
import '../models/check_request.dart';
import '../services/api_client.dart';
import '../services/device_id_service.dart';
import '../services/employee_services.dart';
import '../services/location_service.dart';

/// Các bước của luồng chấm công. Thứ tự: chọn ca (nếu có nhiều) -> quét QR -> vị trí GPS -> khuôn mặt -> gửi -> kết quả.
enum FlowStep { selectShift, qr, location, face, submitting, result }

/// Loại chấm công của một ca, suy ra từ trạng thái hôm nay.
enum CheckAction { checkIn, checkOut, done }

CheckAction actionFor(TodayItem item) {
  final a = item.attendance;
  if (a == null) return CheckAction.checkIn;
  return a.isOpen ? CheckAction.checkOut : CheckAction.done;
}

/// Máy trạng thái của màn chấm công. Mỗi bước thất bại ở lại đúng bước đó để thử lại;
/// server từ chối thì thử lại từ bước QR.
class CheckFlowController extends ChangeNotifier {
  final LocationService location;
  final DeviceIdService device;
  final AttendanceService attendance;

  CheckFlowController({
    required this.location,
    required this.device,
    required this.attendance,
  });

  FlowStep step = FlowStep.selectShift;
  TodayItem? selected;
  String? qrToken;
  LocationReading? position;
  bool faceVerified = false;
  bool busy = false;
  String? error;
  CheckResult? success;
  String? failure;
  bool _disposed = false;

  /// Ca được chọn đang ở trạng thái nào (vào hay ra).
  CheckAction get action => selected == null ? CheckAction.checkIn : actionFor(selected!);
  bool get isCheckOut => action == CheckAction.checkOut;

  /// Các ca còn chấm công được (chưa vào hoặc đã vào chưa ra).
  static List<TodayItem> actionable(List<TodayItem> items) =>
      items.where((i) => actionFor(i) != CheckAction.done).toList();

  /// Ca [item] bị khóa vì đang trong ca [open] chưa check-out (không chấm 2 ca cùng lúc).
  static bool isBlocked(TodayItem item, TodayItem? open) => open != null && item.shift.id != open.shift.id;

  /// Bắt đầu luồng. Chỉ có 1 ca chấm được thì tự chọn, nhiều ca thì hiện danh sách chọn
  /// (đang trong một ca chưa check-out còn trong giờ thì các ca khác hiện mờ, không chọn được: xem [isBlocked]).
  void start(List<TodayItem> items) {
    final options = actionable(items);
    if (options.length == 1) choose(options.first);
  }

  void choose(TodayItem item) {
    selected = item;
    _resetData();
    step = FlowStep.qr;
    _notify();
  }

  void _resetData() {
    qrToken = null;
    position = null;
    faceVerified = false;
    error = null;
    failure = null;
    success = null;
  }

  /// Bước 1: có mã QR (quét hoặc nhập tay) thì sang bước vị trí. Chỉ nhận một lần khi đang ở bước QR.
  Future<void> onQr(String code) async {
    final token = code.trim();
    if (step != FlowStep.qr || token.isEmpty) return;
    qrToken = token;
    await runLocation();
  }

  /// Bước 2: lấy GPS.
  Future<void> runLocation() async {
    if (busy) return;
    step = FlowStep.location;
    busy = true;
    error = null;
    _notify();
    try {
      position = await location.current();
      step = FlowStep.face;
    } on LocationException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Không lấy được vị trí. Vui lòng thử lại.';
    }
    busy = false;
    _notify();
  }

  /// Bước 3 xong: [verified] = true nếu qua thử thách khuôn mặt, false nếu bỏ qua (chỉ để demo).
  Future<void> onFace({required bool verified}) async {
    if (step != FlowStep.face) return;
    faceVerified = verified;
    await _submit();
  }

  Future<void> _submit() async {
    final token = qrToken;
    final pos = position;
    if (token == null || pos == null) return;
    step = FlowStep.submitting;
    error = null;
    _notify();
    try {
      final request = CheckRequest(
        qrToken: token,
        latitude: pos.latitude,
        longitude: pos.longitude,
        isMocked: pos.isMocked,
        deviceId: await device.get(),
        faceVerified: faceVerified,
      );
      success = isCheckOut ? await attendance.checkOut(request) : await attendance.checkIn(request);
      failure = null;
    } on ApiException catch (e) {
      failure = e.message;
      success = null;
    } catch (_) {
      failure = 'Đã xảy ra lỗi không mong muốn. Vui lòng thử lại.';
      success = null;
    }
    step = FlowStep.result;
    _notify();
  }

  /// Server từ chối: làm lại từ bước quét QR.
  void retryAfterFailure() {
    _resetData();
    step = FlowStep.qr;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
