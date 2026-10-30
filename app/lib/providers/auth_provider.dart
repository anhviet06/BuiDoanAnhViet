import 'package:flutter/foundation.dart';

import '../models/auth_session.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Trạng thái đăng nhập toàn app. Màn hình gốc (AuthGate) chọn trang theo [status] và role.
class AuthProvider extends ChangeNotifier {
  final TokenStorage _storage;
  final AuthService _service;

  AuthStatus _status = AuthStatus.unknown;
  AuthSession? _session;
  String? _notice;
  bool _pendingFacePrompt = false;

  AuthProvider(this._storage, this._service);

  /// true ngay sau khi đăng nhập bằng mật khẩu + OTP (để AuthGate hỏi "Bật đăng nhập bằng khuôn mặt?"). Đọc xong thì gọi [consumeFacePrompt].
  bool get pendingFacePrompt => _pendingFacePrompt;
  void consumeFacePrompt() => _pendingFacePrompt = false;

  AuthStatus get status => _status;
  AuthSession? get session => _session;

  /// Thông báo một lần cho màn đăng nhập (vd: phiên hết hạn).
  String? get notice => _notice;

  void clearNotice() => _notice = null;

  /// Gọi lúc mở app: đọc token đã lưu, hỏng/hết hạn thì xóa và về đăng nhập.
  Future<void> init() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
    } else {
      final session = AuthSession.fromToken(token, fullName: await _storage.readFullName());
      if (session == null) {
        await _storage.clear();
        _notice = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
        _status = AuthStatus.unauthenticated;
      } else {
        _session = session;
        _status = AuthStatus.authenticated;
      }
    }
    notifyListeners();
  }

  /// Đăng ký tài khoản nhân viên mới. Server gửi OTP xác thực email; chưa đăng nhập cho tới khi [verifyOtp].
  Future<LoginChallenge> register({
    required String email,
    required String password,
    required String fullName,
    String? username,
  }) =>
      _service.register(email: email.trim(), password: password, fullName: fullName.trim(), username: username?.trim());

  /// Bước 1 (màn đăng nhập). Ném ApiException nếu sai thông tin.
  Future<LoginChallenge> login(String username, String password) => _service.login(username.trim(), password);

  /// Bước 2 (màn OTP): thành công thì lưu token và chuyển màn theo role.
  Future<void> verifyOtp(String username, String otp) async {
    final result = await _service.verifyOtp(username.trim(), otp.trim());
    await acceptLogin(result, fromPassword: true);
  }

  /// Nhận kết quả đăng nhập (OTP hoặc khuôn mặt): lưu token, đặt phiên, chuyển màn theo role.
  /// [fromPassword] = true khi vừa đăng nhập bằng mật khẩu + OTP -> sẽ hỏi bật đăng nhập bằng khuôn mặt.
  Future<void> acceptLogin(VerifyResult result, {bool fromPassword = false}) async {
    final session = AuthSession.fromToken(result.token, fullName: result.fullName);
    if (session == null) {
      throw StateError('Token nhận về không hợp lệ');
    }
    await _storage.saveToken(result.token);
    await _storage.saveFullName(result.fullName);
    _session = session;
    _notice = null;
    _pendingFacePrompt = fromPassword;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// Cập nhật họ tên hiển thị sau khi người dùng tự sửa hồ sơ.
  Future<void> updateFullName(String fullName) async {
    final s = _session;
    if (s == null) return;
    await _storage.saveFullName(fullName);
    _session = AuthSession(
      token: s.token,
      userId: s.userId,
      username: s.username,
      email: s.email,
      fullName: fullName,
      role: s.role,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.clear();
    _session = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// ApiClient gọi khi server trả 401 cho request có token: xóa token và về đăng nhập.
  Future<void> handleUnauthorized() async {
    if (_status != AuthStatus.authenticated) return;
    _notice = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.';
    await logout();
  }
}
