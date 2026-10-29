import 'package:buidoananhviet/services/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

ApiClient clientWith(StubAdapter adapter, FakeTokenStorage storage, {Future<void> Function()? onUnauthorized}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  return ApiClient(storage: storage, dio: dio, onUnauthorized: onUnauthorized);
}

void main() {
  test('gắn Authorization Bearer khi có token', () async {
    final adapter = StubAdapter(200, {'ok': true});
    final api = clientWith(adapter, FakeTokenStorage(token: 'abc'));
    await api.get('/api/x');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer abc');
  });

  test('không gắn header khi chưa đăng nhập', () async {
    final adapter = StubAdapter(200);
    final api = clientWith(adapter, FakeTokenStorage());
    await api.get('/api/x');
    expect(adapter.requests.single.headers.containsKey('Authorization'), false);
  });

  test('401 khi có token -> gọi onUnauthorized và ném ApiException', () async {
    var called = 0;
    final api = clientWith(StubAdapter(401), FakeTokenStorage(token: 'abc'), onUnauthorized: () async => called++);
    await expectLater(api.get('/api/x'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    expect(called, 1);
  });

  test('401 khi chưa có token (sai mật khẩu) -> KHÔNG gọi onUnauthorized, giữ message server', () async {
    var called = 0;
    final api = clientWith(
        StubAdapter(401, {'success': false, 'message': 'Sai tên đăng nhập hoặc mật khẩu'}), FakeTokenStorage(),
        onUnauthorized: () async => called++);
    await expectLater(
        api.post('/api/Authenticate/login', data: {}),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Sai tên đăng nhập hoặc mật khẩu')));
    expect(called, 0);
  });

  test('ProblemDetails 400 -> lấy thông báo lỗi đầu tiên', () async {
    final api = clientWith(
        StubAdapter(400, {
          'title': 'One or more validation errors occurred.',
          'errors': {
            'Email': ['Email không hợp lệ']
          }
        }),
        FakeTokenStorage());
    await expectLater(api.post('/x', data: {}), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email không hợp lệ')));
  });

  test('409 và 500 trả đúng status', () async {
    await expectLater(clientWith(StubAdapter(409, {'message': 'Đã tồn tại'}), FakeTokenStorage()).put('/x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
    await expectLater(clientWith(StubAdapter(500, 'Internal server error'), FakeTokenStorage()).get('/x'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Internal server error')));
  });
}
