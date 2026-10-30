import 'package:dio/dio.dart';

import 'helpers.dart';

String isoDay(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String monthKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

Map<String, dynamic> record(int id, DateTime workDate, {String status = 'on-time', String shift = 'Ca sáng', bool open = false, int late = 0, String? reason, double hours = 4, double pay = 120000}) => {
      'id': id,
      'userId': 2,
      'userName': 'Nguyễn Văn An',
      'shiftId': 1,
      'shiftName': shift,
      'shiftStartTime': '08:00:00',
      'shiftEndTime': '12:00:00',
      'workDate': '${isoDay(workDate)}T00:00:00',
      'checkInAt': '${isoDay(workDate)}T01:00:00Z',
      'checkOutAt': open ? null : '${isoDay(workDate)}T05:00:00Z',
      'distanceMeters': 12.5,
      'status': status,
      'suspiciousReason': reason,
      'isMockedLocation': false,
      'lateMinutes': late,
      'workedHours': open ? 0 : hours,
      'latePenalty': late * 1000,
      'grossPay': open ? 0 : hours * 30000,
      'pay': open ? 0 : pay,
    };

/// Backend giả có trạng thái cho các màn nhân viên (nhân viên đang đăng nhập có id = 2).
class FakeEmployeeBackend {
  final DateTime now = DateTime.now();
  late final DateTime thisMonth = DateTime(now.year, now.month);
  late final DateTime prevMonth = DateTime(now.year, now.month - 1);

  bool onLeave = false;
  /// Giờ máy chủ giả: mặc định 23:30 hôm nay để các ca mặc định (kết thúc 12:00/17:30) luôn đã qua giờ, không phụ thuộc giờ chạy test.
  late DateTime serverTime = DateTime(now.year, now.month, now.day, 23, 30);
  bool failToday = false;
  List<Map<String, dynamic>> todayShifts = [
    {'id': 1, 'name': 'Ca sáng', 'startTime': '08:00:00', 'endTime': '12:00:00', 'lateGraceMinutes': 5},
    {'id': 2, 'name': 'Ca chiều', 'startTime': '13:30:00', 'endTime': '17:30:00', 'lateGraceMinutes': 10},
  ];
  Map<int, Map<String, dynamic>> todayAttendance = {};
  late List<Map<String, dynamic>> records;
  Map<String, dynamic> me = {
    'id': 2, 'email': 'an.nguyen@timeguard.local', 'username': 'annguyen', 'fullName': 'Nguyễn Văn An',
    'role': 'employee', 'hourlyRate': 30000, 'isLocked': false, 'createdAt': '2026-10-29T01:00:00Z',
  };
  String password = 'matkhau1';
  final leaves = <Map<String, dynamic>>[
    {'id': 1, 'userId': 2, 'user': null, 'fromDate': '2026-11-10T00:00:00', 'toDate': '2026-11-12T00:00:00', 'reason': 'Việc gia đình', 'status': 'pending', 'adminNote': null, 'createdAt': '2026-10-29T01:00:00Z'},
    {'id': 2, 'userId': 2, 'user': null, 'fromDate': '2026-12-01T00:00:00', 'toDate': '2026-12-01T00:00:00', 'reason': 'Khám bệnh', 'status': 'approved', 'adminNote': 'Duyệt rồi nhé', 'createdAt': '2026-10-20T01:00:00Z'},
  ];
  var _nextLeave = 10;
  late final FakeBackend adapter;

  FakeEmployeeBackend() {
    records = [
      record(1, DateTime(thisMonth.year, thisMonth.month, 1), status: 'late', late: 20, hours: 3.5, pay: 85000),
      record(2, DateTime(thisMonth.year, thisMonth.month, 1), status: 'suspicious', shift: 'Ca chiều', reason: 'GPS giả (mock location)', pay: 120000),
      record(3, DateTime(thisMonth.year, thisMonth.month, 1), open: true, shift: 'Ca tối'),
      record(4, DateTime(prevMonth.year, prevMonth.month, 5), hours: 4, pay: 100000),
    ];
    adapter = FakeBackend(_handle);
  }

  Map<String, dynamic> summary(String month) {
    if (month == monthKey(thisMonth)) {
      return {
        'userId': 2, 'fullName': 'Nguyễn Văn An', 'hourlyRate': 30000, 'daysWorked': 2, 'openCount': 1, 'totalHours': 7.5,
        'lateCount': 1, 'totalLateMinutes': 20, 'totalPenalty': 20000, 'grossPay': 250000, 'netPay': 230000,
        'suspiciousCount': 1, 'suspiciousPay': 120000, 'leaveDays': 2,
        'days': [
          {'date': '${isoDay(thisMonth)}T00:00:00', 'hours': 3.5, 'lateMinutes': 20, 'penalty': 20000, 'pay': 85000, 'status': 'late'},
          {'date': '${isoDay(DateTime(thisMonth.year, thisMonth.month, 2))}T00:00:00', 'hours': 4, 'lateMinutes': 0, 'penalty': 0, 'pay': 120000, 'status': 'on-time'},
        ],
      };
    }
    return {
      'userId': 2, 'fullName': 'Nguyễn Văn An', 'hourlyRate': 30000, 'daysWorked': 1, 'openCount': 0, 'totalHours': 4,
      'lateCount': 0, 'totalLateMinutes': 0, 'totalPenalty': 0, 'grossPay': 120000, 'netPay': 100000,
      'suspiciousCount': 0, 'suspiciousPay': 0, 'leaveDays': 0, 'days': [],
    };
  }

  ({int status, Object? body}) _handle(RequestOptions o) {
    final seg = o.path.split('/').where((s) => s.isNotEmpty).toList();
    final body = (o.data is Map ? o.data : <String, dynamic>{}) as Map;
    const ok = (status: 204, body: null);
    switch (seg[1]) {
      case 'Attendances':
        if (seg.length > 2 && seg[2] == 'today') {
          if (failToday) return (status: 500, body: 'Internal server error');
          return (
            status: 200,
            body: {
              'date': '${isoDay(now)}T00:00:00',
              'serverTime': serverTime.toIso8601String(),
              'onLeave': onLeave,
              'items': [for (final s in todayShifts) {'shift': s, 'attendance': todayAttendance[s['id']]}],
            }
          );
        }
        if (seg.length > 2 && (seg[2] == 'check-in' || seg[2] == 'check-out')) return _check(seg[2], body);
        final from = o.queryParameters['from'] as String;
        final to = o.queryParameters['to'] as String;
        return (
          status: 200,
          body: records.where((r) {
            final d = (r['workDate'] as String).substring(0, 10);
            return d.compareTo(from) >= 0 && d.compareTo(to) <= 0;
          }).toList()
        );
      case 'Reports':
        final month = o.queryParameters['month'] as String;
        return (status: 200, body: {'month': month, 'rows': [summary(month)]});
      case 'Users':
        if (seg[2] == 'me') {
          if (o.method == 'GET') return (status: 200, body: me);
          // giống server: không gửi = giữ nguyên, chuỗi rỗng = xóa (họ tên không được rỗng)
          if (body.containsKey('fullName')) {
            if ((body['fullName'] as String).trim().isEmpty) return (status: 400, body: {'success': false, 'message': 'Họ và tên không được để trống'});
            me['fullName'] = body['fullName'];
          }
          for (final k in ['phone', 'dateOfBirth', 'address']) {
            if (body.containsKey(k)) me[k] = (body[k] as String).isEmpty ? null : (k == 'dateOfBirth' ? '${body[k]}T00:00:00' : body[k]);
          }
          return ok;
        }
        if (seg[2] == 'change-password') {
          if (body['currentPassword'] != password) {
            return (status: 400, body: {'success': false, 'message': 'Mật khẩu hiện tại không đúng'});
          }
          password = body['newPassword'] as String;
          return (status: 200, body: {'success': true, 'message': 'Đổi mật khẩu thành công'});
        }
        break;
      case 'Leaves':
        if (o.method == 'GET') return (status: 200, body: leaves.reversed.toList());
        if (o.method == 'POST') {
          final from = '${body['fromDate']}T00:00:00';
          if (leaves.any((l) => l['status'] != 'rejected' && (l['fromDate'] as String).compareTo('${body['toDate']}T00:00:00') <= 0 && (l['toDate'] as String).compareTo(from) >= 0)) {
            return (status: 400, body: {'success': false, 'message': 'Khoảng ngày này trùng với một đơn nghỉ khác'});
          }
          final l = {'id': _nextLeave++, 'userId': 2, 'user': null, 'fromDate': from, 'toDate': '${body['toDate']}T00:00:00', 'reason': body['reason'], 'status': 'pending', 'adminNote': null, 'createdAt': '2026-10-29T01:00:00Z'};
          leaves.add(l);
          return (status: 201, body: l);
        }
        final leave = leaves.where((l) => '${l['id']}' == seg[2]).firstOrNull;
        if (leave == null) return (status: 404, body: null);
        if (leave['status'] != 'pending') {
          return (status: 409, body: {'success': false, 'message': 'Chỉ sửa được đơn đang chờ duyệt'});
        }
        if (o.method == 'DELETE') {
          leaves.remove(leave);
          return ok;
        }
        leave..['fromDate'] = '${body['fromDate']}T00:00:00'..['toDate'] = '${body['toDate']}T00:00:00'..['reason'] = body['reason'];
        return ok;
    }
    return (status: 404, body: null);
  }

  /// Mã QR hợp lệ -> id ca (giống backend: qrToken xác định ca).
  static const qrTokens = {'token-sang': 1, 'token-chieu': 2};

  ({int status, Object? body}) _check(String kind, Map body) {
    const fail400 = 400;
    final shiftId = qrTokens[body['qrToken']];
    if (shiftId == null) return (status: fail400, body: {'success': false, 'message': 'Mã QR không hợp lệ hoặc ca không còn hoạt động'});
    if ((body['latitude'] as num) > 21.3) {
      return (status: fail400, body: {'success': false, 'message': 'Bạn đang cách công ty 5000 m, vượt bán kính cho phép 100 m'});
    }
    final shift = todayShifts.firstWhere((s) => s['id'] == shiftId);
    final existing = todayAttendance[shiftId];
    final name = shift['name'] as String;
    final mocked = body['isMocked'] == true;
    if (kind == 'check-in') {
      if (onLeave) return (status: fail400, body: {'success': false, 'message': 'Hôm nay bạn có đơn nghỉ phép đã được duyệt, không thể chấm công'});
      if (existing != null) return (status: 409, body: {'success': false, 'message': 'Bạn đã check-in ca này hôm nay'});
      final rec = record(100 + shiftId, now, shift: name, open: true, status: mocked ? 'suspicious' : 'on-time', reason: mocked ? 'GPS giả (mock location)' : null);
      rec['deviceId'] = body['deviceId'];
      rec['faceVerified'] = body['faceVerified'] == true;
      todayAttendance[shiftId] = rec;
      return (status: 200, body: {'success': true, 'message': mocked ? 'Check-in thành công nhưng bị đánh dấu nghi ngờ: GPS giả (mock location)' : 'Check-in thành công', 'attendance': rec});
    }
    if (existing == null) return (status: fail400, body: {'success': false, 'message': 'Bạn chưa check-in ca này hôm nay'});
    if (existing['checkOutAt'] != null) return (status: 409, body: {'success': false, 'message': 'Bạn đã check-out ca này rồi'});
    existing
      ..['checkOutFaceVerified'] = body['faceVerified'] == true
      ..['checkOutAt'] = '${isoDay(now)}T05:00:00Z'
      ..['workedHours'] = 4
      ..['grossPay'] = 120000
      ..['pay'] = 120000;
    return (status: 200, body: {'success': true, 'message': 'Check-out thành công', 'attendance': existing});
  }
}
