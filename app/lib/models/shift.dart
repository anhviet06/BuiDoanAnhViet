import 'package:flutter/material.dart';

/// Ca làm việc. [qrToken] chỉ có khi admin gọi API (nhân viên không nhận được).
class Shift {
  final int id;
  final String name;
  final String startTime; // "08:00:00"
  final String endTime;
  final int lateGraceMinutes;
  final String? qrToken;
  final bool isActive;

  const Shift({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.lateGraceMinutes,
    required this.isActive,
    this.qrToken,
  });

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
        startTime: (json['startTime'] ?? '00:00:00') as String,
        endTime: (json['endTime'] ?? '00:00:00') as String,
        lateGraceMinutes: (json['lateGraceMinutes'] ?? 0) as int,
        isActive: (json['isActive'] ?? true) as bool,
        qrToken: json['qrToken'] as String?,
      );

  /// "08:00" từ "08:00:00". Giờ kết thúc hết ngày (server lưu 23:59:59.9999999) hiển thị đúng "24:00".
  String get startLabel => clock(startTime);
  String get endLabel => clock(endTime);
  String get rangeLabel => '$startLabel - $endLabel';

  /// Ca kết thúc lúc 24:00 (hết ngày).
  bool get endsAtMidnight => isEndOfDayValue(endTime);

  /// Số phút từ 00:00 tới giờ kết thúc (24:00 = 1440).
  int get endMinutes => endsAtMidnight ? 24 * 60 : end.hour * 60 + end.minute;

  /// "24:00" hoặc "23:59:59.9999999" -> true.
  static bool isEndOfDayValue(String v) => v.startsWith('24:00') || v.startsWith('23:59:59');

  /// Nhãn giờ "HH:mm" từ chuỗi giờ của server; giờ hết ngày thành "24:00".
  static String clock(String v) => isEndOfDayValue(v) ? '24:00' : (v.length >= 5 ? v.substring(0, 5) : v);

  TimeOfDay get start => parseTime(startTime);
  TimeOfDay get end => parseTime(endTime);

  static TimeOfDay parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
  }

  /// Định dạng gửi lên server: "HH:mm".
  static String format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
