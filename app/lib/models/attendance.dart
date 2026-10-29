import 'shift.dart';

/// Bản ghi chấm công (dạng server trả qua AttendanceView). Giờ check-in/out là UTC;
/// [workDate] là ngày làm việc theo giờ địa phương của công ty (không đổi múi giờ).
class Attendance {
  final int id;
  final int userId;
  final String? userName;
  final int shiftId;
  final String? shiftName;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final DateTime workDate;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final double distanceMeters;
  final String status; // on-time | late | suspicious
  final String? suspiciousReason;
  final bool isMockedLocation;
  final int lateMinutes;
  final double workedHours;
  final double latePenalty;
  final double grossPay;
  final double pay;
  final bool faceVerified; // đã xác thực khuôn mặt lúc check-in
  final bool? checkOutFaceVerified; // lúc check-out (null = chưa check-out)
  final String? adminAction; // reviewed | closed
  final String? adminNote;
  final DateTime? adminActionAt;

  const Attendance({
    required this.id,
    required this.userId,
    required this.shiftId,
    required this.workDate,
    required this.checkInAt,
    required this.status,
    this.userName,
    this.shiftName,
    this.shiftStartTime,
    this.shiftEndTime,
    this.checkOutAt,
    this.distanceMeters = 0,
    this.suspiciousReason,
    this.isMockedLocation = false,
    this.lateMinutes = 0,
    this.workedHours = 0,
    this.latePenalty = 0,
    this.grossPay = 0,
    this.pay = 0,
    this.faceVerified = false,
    this.checkOutFaceVerified,
    this.adminAction,
    this.adminNote,
    this.adminActionAt,
  });

  bool get isOpen => checkOutAt == null;
  bool get isSuspicious => status == 'suspicious';
  bool get wasReviewed => adminAction == 'reviewed';
  bool get wasClosedByAdmin => adminAction == 'closed';

  String get shiftRange =>
      (shiftStartTime == null || shiftEndTime == null) ? '' : '${_hm(shiftStartTime!)} - ${_hm(shiftEndTime!)}';

  static String _hm(String v) => Shift.clock(v);

  static double _d(dynamic v) => ((v ?? 0) as num).toDouble();

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
        id: json['id'] as int,
        userId: json['userId'] as int,
        userName: json['userName'] as String?,
        shiftId: json['shiftId'] as int,
        shiftName: json['shiftName'] as String?,
        shiftStartTime: json['shiftStartTime'] as String?,
        shiftEndTime: json['shiftEndTime'] as String?,
        workDate: DateTime.parse(json['workDate'] as String),
        checkInAt: DateTime.parse(json['checkInAt'] as String),
        checkOutAt: json['checkOutAt'] == null ? null : DateTime.parse(json['checkOutAt'] as String),
        distanceMeters: _d(json['distanceMeters']),
        status: (json['status'] ?? 'on-time') as String,
        suspiciousReason: json['suspiciousReason'] as String?,
        isMockedLocation: (json['isMockedLocation'] ?? false) as bool,
        lateMinutes: (json['lateMinutes'] ?? 0) as int,
        workedHours: _d(json['workedHours']),
        latePenalty: _d(json['latePenalty']),
        grossPay: _d(json['grossPay']),
        pay: _d(json['pay']),
        faceVerified: (json['faceVerified'] ?? false) as bool,
        checkOutFaceVerified: json['checkOutFaceVerified'] as bool?,
        adminAction: json['adminAction'] as String?,
        adminNote: json['adminNote'] as String?,
        adminActionAt: json['adminActionAt'] == null ? null : DateTime.parse(json['adminActionAt'] as String),
      );
}

/// Một ca trong ngày kèm bản ghi chấm công của nhân viên (nếu đã chấm).
class TodayItem {
  final Shift shift;
  final Attendance? attendance;

  const TodayItem(this.shift, this.attendance);
}

/// Dữ liệu dashboard "Hôm nay" (GET /api/Attendances/today).
class TodayInfo {
  final DateTime date;
  final DateTime serverTime; // giờ địa phương của công ty
  final bool onLeave;
  final List<TodayItem> items;

  const TodayInfo({required this.date, required this.serverTime, required this.onLeave, required this.items});

  /// Ca đang mở (đã check-in chưa check-out) mà CÒN trong giờ của ca: khi đó không được chấm ca khác.
  TodayItem? get openInHours => openShiftInHours(items, serverTime);

  /// Server trả giờ ĐỊA PHƯƠNG của công ty nhưng JSON có hậu tố "Z": bỏ múi giờ, chỉ lấy giờ trên đồng hồ
  /// để so sánh được với ngày làm việc (không có múi giờ), không bị lệch theo múi giờ của thiết bị.
  static DateTime _wallClock(DateTime d) => DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second, d.millisecond);

  factory TodayInfo.fromJson(Map<String, dynamic> json) => TodayInfo(
        date: DateTime.parse(json['date'] as String),
        serverTime: _wallClock(DateTime.parse(json['serverTime'] as String)),
        onLeave: (json['onLeave'] ?? false) as bool,
        items: (json['items'] as List)
            .map((e) => TodayItem(
                  Shift.fromJson((e as Map<String, dynamic>)['shift'] as Map<String, dynamic>),
                  e['attendance'] == null ? null : Attendance.fromJson(e['attendance'] as Map<String, dynamic>),
                ))
            .toList(),
      );
}

/// Ca đang mở còn trong giờ (ngày làm việc + giờ kết thúc ca chưa qua so với [now]); null nếu không có.
/// Ca đã quá giờ mà quên check-out KHÔNG tính (không chặn ca khác, admin xử lý bằng "Đóng ca").
TodayItem? openShiftInHours(List<TodayItem> items, DateTime? now) {
  if (now == null) return null;
  for (final i in items) {
    final a = i.attendance;
    if (a == null || !a.isOpen) continue;
    final day = DateTime(a.workDate.year, a.workDate.month, a.workDate.day);
    if (day.add(Duration(minutes: i.shift.endMinutes)).isAfter(now)) return i;
  }
  return null;
}
