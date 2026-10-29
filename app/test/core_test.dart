import 'package:buidoananhviet/core/format.dart';
import 'package:buidoananhviet/core/jwt_utils.dart';
import 'package:buidoananhviet/models/attendance.dart';
import 'package:buidoananhviet/models/auth_session.dart';
import 'package:buidoananhviet/models/shift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'helpers.dart';

void main() {
  group('JwtUtils / AuthSession', () {
    test('đọc claim role/username từ token backend', () {
      final s = AuthSession.fromToken(makeJwt(role: 'admin', name: 'admin'), fullName: 'Quản trị viên')!;
      expect(s.isAdmin, true);
      expect(s.userId, 2);
      expect(s.username, 'admin');
      expect(s.fullName, 'Quản trị viên');
    });

    test('token hết hạn / hỏng / role lạ -> null', () {
      expect(AuthSession.fromToken(makeJwt(expiresIn: const Duration(minutes: -1))), isNull);
      expect(AuthSession.fromToken('khong-phai-jwt'), isNull);
      expect(AuthSession.fromToken(makeJwt(role: 'boss')), isNull);
    });

    test('isExpired', () {
      expect(JwtUtils.isExpired(makeJwt()), false);
      expect(JwtUtils.isExpired(makeJwt(expiresIn: const Duration(seconds: -5))), true);
      expect(JwtUtils.isExpired('abc'), true);
    });
  });

  group('Fmt', () {
    setUpAll(() => initializeDateFormatting('vi'));

    test('tiền dạng ngắn cho trục biểu đồ', () {
      expect(Fmt.compactMoney(1500000), '1,5tr');
      expect(Fmt.compactMoney(2000000), '2tr');
      expect(Fmt.compactMoney(45000), '45k');
      expect(Fmt.compactMoney(0), '0');
    });

    test('tiền, ngày, giờ ca', () {
      expect(Fmt.money(1500000).replaceAll(RegExp(r'\s'), ' '), '1.500.000 ₫');
      expect(Fmt.date(DateTime(2026, 10, 29)), '29/10/2026');
      expect(Fmt.span('08:00:00'), '08:00');
      expect(Fmt.hours(0.5), '0,5 giờ');
    });
  });

  group('Giờ ca 24:00 và ca đang mở còn trong giờ', () {
    Shift shift(int id, String start, String end) => Shift(id: id, name: 'Ca $id', startTime: start, endTime: end, lateGraceMinutes: 5, isActive: true);
    Attendance open(int shiftId, DateTime day) => Attendance(
        id: shiftId, userId: 1, shiftId: shiftId, workDate: day, checkInAt: day.add(const Duration(hours: 1)), status: 'on-time');

    test('server lưu 23:59:59.9999999 -> hiển thị "24:00"; giờ thường giữ nguyên', () {
      expect(shift(3, '18:00:00', '23:59:59.9999999').rangeLabel, '18:00 - 24:00');
      expect(shift(3, '18:00:00', '23:59:59.9999999').endsAtMidnight, true);
      expect(shift(3, '18:00:00', '23:59:59.9999999').endMinutes, 1440);
      expect(shift(1, '06:00:00', '12:00:00').rangeLabel, '06:00 - 12:00');
      expect(shift(1, '06:00:00', '12:00:00').endsAtMidnight, false);
      expect(Shift.clock('24:00'), '24:00');
    });

    test('serverTime có hậu tố Z (giờ địa phương công ty) được đọc theo đồng hồ, không lệch theo múi giờ máy', () {
      final info = TodayInfo.fromJson({
        'date': '2026-10-29T00:00:00',
        'serverTime': '2026-10-29T19:44:12.1234567Z',
        'onLeave': false,
        'items': [
          {
            'shift': {'id': 3, 'name': 'Ca 3', 'startTime': '18:00:00', 'endTime': '23:59:59.9999999', 'lateGraceMinutes': 5},
            'attendance': {
              'id': 1, 'userId': 1, 'shiftId': 3, 'workDate': '2026-10-29T00:00:00', 'checkInAt': '2026-10-29T12:43:00Z', 'status': 'late',
            },
          },
        ],
      });
      expect(info.serverTime.isUtc, false);
      expect((info.serverTime.hour, info.serverTime.minute), (19, 44));
      expect(info.openInHours?.shift.id, 3);
    });

    test('openShiftInHours: còn trong giờ thì có, quá giờ hoặc đã check-out thì không', () {
      final day = DateTime(2026, 10, 29);
      final a = shift(1, '00:00:00', '12:00:00');
      final items = [TodayItem(a, open(1, day)), TodayItem(shift(2, '06:00:00', '12:00:00'), null)];
      expect(openShiftInHours(items, DateTime(2026, 10, 29, 11, 59))?.shift.id, 1);
      expect(openShiftInHours(items, DateTime(2026, 10, 29, 12, 0)), isNull);
      expect(openShiftInHours(items, null), isNull);
      // ca 24:00 mở hôm qua: đã qua 00:00 hôm nay nên không còn trong giờ
      final night = shift(3, '18:00:00', '23:59:59.9999999');
      expect(openShiftInHours([TodayItem(night, open(3, DateTime(2026, 10, 28)))], DateTime(2026, 10, 29, 0, 5)), isNull);
      expect(openShiftInHours([TodayItem(night, open(3, day))], DateTime(2026, 10, 29, 23, 50))?.shift.id, 3);
    });
  });
}
