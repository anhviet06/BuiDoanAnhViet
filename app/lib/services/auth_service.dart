import 'api_client.dart';

/// Kết quả bước 1 đăng nhập. [devOtp] chỉ có khi backend bật Otp:DevMode (demo).
class LoginChallenge {
  final String message;
  final String? devOtp;

  const LoginChallenge(this.message, this.devOtp);
}

/// Kết quả bước 2: token + thông tin người dùng.
class VerifyResult {
  final String token;
  final String fullName;

  const VerifyResult(this.token, this.fullName);
}

/// Gọi các API xác thực của backend (/api/Authenticate/*).
class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  /// Đăng ký tài khoản; server gửi OTP xác thực email ngay (giống bước 1 đăng nhập).
  /// Chưa có JWT cho tới khi [verifyOtp] thành công. [LoginChallenge.devOtp] chỉ có khi backend bật Otp:DevMode.
  Future<LoginChallenge> register({
    required String email,
    required String password,
    required String fullName,
    String? username,
  }) async {
    final data = await _api.post('/api/Authenticate/register', data: {
      'email': email,
      'password': password,
      'fullName': fullName,
      if (username != null && username.isNotEmpty) 'username': username,
    });
    return LoginChallenge((data['message'] ?? '') as String, data['devOtp'] as String?);
  }

  /// Bước 1: tài khoản + mật khẩu -> server gửi OTP.
  Future<LoginChallenge> login(String username, String password) async {
    final data = await _api.post('/api/Authenticate/login', data: {'username': username, 'password': password});
    return LoginChallenge((data['message'] ?? '') as String, data['devOtp'] as String?);
  }

  /// Bước 2: OTP -> JWT.
  Future<VerifyResult> verifyOtp(String username, String otp) async {
    final data = await _api.post('/api/Authenticate/verify-otp', data: {'username': username, 'otp': otp});
    final user = data['user'] as Map<String, dynamic>?;
    return VerifyResult(data['token'] as String, (user?['fullName'] ?? '') as String);
  }
}
