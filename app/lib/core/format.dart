import 'package:intl/intl.dart';

/// Định dạng hiển thị tiếng Việt dùng chung.
class Fmt {
  static final NumberFormat _money = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'vi');
  static final DateFormat _time = DateFormat('HH:mm', 'vi');
  static final DateFormat _dateTime = DateFormat('HH:mm dd/MM/yyyy', 'vi');

  static final DateFormat _weekdayDate = DateFormat('EEEE, dd/MM/yyyy', 'vi');
  static final DateFormat _weekdayShort = DateFormat('EEE', 'vi');

  /// "Thứ Năm, 29/10/2026".
  static String weekdayDate(DateTime value) => _weekdayDate.format(value);

  /// Thứ viết tắt: "Th 5", "CN".
  static String weekdayShort(DateTime value) => _weekdayShort.format(value);

  /// Tiền dạng ngắn cho trục biểu đồ: 1.500.000 -> "1,5tr", 45.000 -> "45k".
  static String compactMoney(num value) {
    final v = value.abs();
    if (v >= 1000000) return '${NumberFormat('0.#', 'vi').format(value / 1000000)}tr';
    if (v >= 1000) return '${NumberFormat('0.#', 'vi').format(value / 1000)}k';
    return NumberFormat('0.#', 'vi').format(value);
  }

  static String money(num value) => _money.format(value);

  /// Ngày (không đổi múi giờ: dùng cho WorkDate / ngày nghỉ phép là ngày địa phương).
  static String date(DateTime value) => _date.format(value);

  /// Giờ:phút theo giờ máy (tự đổi UTC -> local nếu là UTC).
  static String time(DateTime value) => _time.format(value.toLocal());

  static String dateTime(DateTime value) => _dateTime.format(value.toLocal());

  /// "08:00:00" (TimeSpan của server) -> "08:00".
  static String span(String value) => value.length >= 5 ? value.substring(0, 5) : value;

  static String hours(num value) => '${NumberFormat('0.##', 'vi').format(value)} giờ';
}
