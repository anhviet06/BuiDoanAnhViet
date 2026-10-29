/// Validator dùng chung cho các form (thông báo tiếng Việt).
class Validators {
  static String? required(String? value, [String field = 'Trường này']) =>
      (value == null || value.trim().isEmpty) ? '$field không được để trống' : null;

  static String? email(String? value) {
    final empty = required(value, 'Email');
    if (empty != null) return empty;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim()) ? null : 'Email không hợp lệ';
  }

  static String? password(String? value) {
    final empty = required(value, 'Mật khẩu');
    if (empty != null) return empty;
    return value!.length < 6 ? 'Mật khẩu tối thiểu 6 ký tự' : null;
  }

  static String? otp(String? value) {
    final empty = required(value, 'Mã OTP');
    if (empty != null) return empty;
    return RegExp(r'^\d{6}$').hasMatch(value!.trim()) ? null : 'Mã OTP gồm 6 chữ số';
  }

  /// Tên đăng nhập tùy chọn: để trống được, nếu nhập thì tối thiểu 3 ký tự, không có khoảng trắng.
  static String? optionalUsername(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length < 3) return 'Tên đăng nhập tối thiểu 3 ký tự';
    return v.contains(RegExp(r'\s')) ? 'Tên đăng nhập không được chứa khoảng trắng' : null;
  }
}
