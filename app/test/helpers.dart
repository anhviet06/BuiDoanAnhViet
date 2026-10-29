import 'dart:convert';

import 'package:buidoananhviet/app.dart';
import 'package:buidoananhviet/app_providers.dart';
import 'package:buidoananhviet/services/location_service.dart';
import 'package:buidoananhviet/providers/auth_provider.dart';
import 'package:buidoananhviet/services/api_client.dart';
import 'package:buidoananhviet/services/auth_service.dart';
import 'package:buidoananhviet/services/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// TokenStorage giữ trong bộ nhớ, dùng cho test.
class FakeTokenStorage implements TokenStorage {
  String? token;
  String? fullName;
  String? deviceId;

  FakeTokenStorage({this.token, this.fullName, this.deviceId});

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> saveToken(String value) async => token = value;

  @override
  Future<String?> readFullName() async => fullName;

  @override
  Future<void> saveFullName(String value) async => fullName = value;

  @override
  Future<String?> readDeviceId() async => deviceId;

  @override
  Future<void> saveDeviceId(String value) async => deviceId = value;

  @override
  Future<void> clear() async {
    token = null;
    fullName = null;
  }
}

/// Dựng JWT giả (chưa ký) có cùng tên claim như backend phát ra.
String makeJwt({String role = 'employee', Duration expiresIn = const Duration(hours: 1), String name = 'annguyen', int userId = 2}) {
  String enc(Map<String, dynamic> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().toUtc().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({
        'nameid': '$userId',
        'unique_name': name,
        'email': '$name@timeguard.local',
        'role': role,
        'exp': exp,
      })}.sig';
}

/// Adapter dio trả về phản hồi cố định, đồng thời ghi lại các request đã gửi.
class StubAdapter implements HttpClientAdapter {
  final int status;
  final Object? body;
  final List<RequestOptions> requests = [];

  StubAdapter(this.status, [this.body = const <String, dynamic>{}]);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Backend giả: [handler] nhận request và trả (status, body).
class FakeBackend implements HttpClientAdapter {
  final ({int status, Object? body}) Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  /// Ghi đè tạm thời cho từng test: trả null thì dùng [handler] như bình thường.
  ({int status, Object? body})? Function(RequestOptions options)? interceptor;

  FakeBackend(this.handler);

  List<RequestOptions> to(String path) => requests.where((r) => r.path == path).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final r = interceptor?.call(options) ?? handler(options);
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Vị trí GPS giả cho test.
class FakeLocationService implements LocationService {
  LocationReading? reading;
  LocationException? error;

  FakeLocationService({this.reading, this.error});

  @override
  Future<LocationReading> current() async {
    if (error != null) throw error!;
    return reading ?? const LocationReading(21.0285, 105.8542);
  }
}

/// Khung xác thực khuôn mặt giả: nút "Xác thực thử" gọi onVerified (camera/ML Kit chỉ chạy được trên thiết bị).
class FakeFaceLiveness {
  int builds = 0;

  Widget build(BuildContext context, {required VoidCallback onVerified}) {
    builds++;
    return Center(child: TextButton(key: const Key('fake_face_ok'), onPressed: onVerified, child: const Text('Xác thực thử')));
  }
}

/// Khung quét QR giả: có nút "Quét thử" (phát ra [code]) và, nếu [errorMessage] != null, báo lỗi camera ngay.
class FakeQrScanner {
  String code;
  String? errorMessage;
  int builds = 0;

  FakeQrScanner({this.code = 'token-sang', this.errorMessage});

  Widget build(BuildContext context, {required void Function(String) onCode, required void Function(String) onError}) {
    builds++;
    return _FakeScannerView(code: code, errorMessage: errorMessage, onCode: onCode, onError: onError);
  }
}

class _FakeScannerView extends StatefulWidget {
  final String code;
  final String? errorMessage;
  final void Function(String) onCode;
  final void Function(String) onError;

  const _FakeScannerView({required this.code, required this.errorMessage, required this.onCode, required this.onError});

  @override
  State<_FakeScannerView> createState() => _FakeScannerViewState();
}

class _FakeScannerViewState extends State<_FakeScannerView> {
  @override
  void initState() {
    super.initState();
    if (widget.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onError(widget.errorMessage!));
    }
  }

  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(key: const Key('fake_scan'), onPressed: () => widget.onCode(widget.code), child: const Text('Quét thử')),
      );
}

/// Dựng app với storage giả và adapter giả, nối dây đúng như main.dart.
({AuthProvider auth, ApiClient api, Widget app}) buildTestApp(
  FakeTokenStorage storage,
  HttpClientAdapter adapter, {
  LocationService? location,
  FakeFaceLiveness? face,
  FakeQrScanner? scanner,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  final api = ApiClient(storage: storage, dio: dio);
  final auth = AuthProvider(storage, AuthService(api));
  api.onUnauthorized = auth.handleUnauthorized;
  final app = MultiProvider(
    providers: buildAppProviders(
      api: api,
      auth: auth,
      location: location ?? FakeLocationService(),
      faceLiveness: (face ?? FakeFaceLiveness()).build,
      qrScanner: (scanner ?? FakeQrScanner()).build,
    ),
    child: const TimeGuardApp(),
  );
  return (auth: auth, api: api, app: app);
}
