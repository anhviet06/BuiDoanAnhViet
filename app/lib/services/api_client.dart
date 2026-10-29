import 'package:dio/dio.dart';

import '../core/config.dart';
import 'token_storage.dart';

/// Lỗi gọi API đã được chuẩn hóa: [message] luôn là tiếng Việt/đọc được để hiện cho người dùng.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}

/// Client HTTP duy nhất của app (dio). Tự gắn JWT; khi server trả 401 cho một request
/// có gắn token thì gọi [onUnauthorized] (AuthProvider sẽ xóa token và về màn đăng nhập).
class ApiClient {
  final Dio dio;
  final TokenStorage storage;
  Future<void> Function()? onUnauthorized;

  ApiClient({required this.storage, Dio? dio, this.onUnauthorized})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            )) {
    this.dio.interceptors.add(InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await storage.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
          onError: (error, handler) async {
            final hadToken = error.requestOptions.headers.containsKey('Authorization');
            if (error.response?.statusCode == 401 && hadToken) {
              await onUnauthorized?.call();
            }
            handler.next(error);
          },
        ));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? data}) => _send('POST', path, data: data);
  Future<dynamic> put(String path, {Object? data}) => _send('PUT', path, data: data);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Object? data, Map<String, dynamic>? query}) async {
    try {
      final response = await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
      );
      return response.data;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  static ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return const ApiException('Máy chủ phản hồi quá chậm. Vui lòng thử lại.');
        default:
          return const ApiException('Không kết nối được máy chủ. Kiểm tra mạng và địa chỉ API.');
      }
    }

    final data = e.response?.data;
    String? message;
    if (data is Map) {
      if (data['message'] is String) {
        message = data['message'] as String;
      } else if (data['errors'] is Map) {
        // ProblemDetails của ASP.NET: errors = { Field: [msg, ...] }
        final first = (data['errors'] as Map).values.expand((v) => v is List ? v : [v]).map((v) => v.toString());
        message = first.isNotEmpty ? first.first : null;
      } else if (data['title'] is String) {
        message = data['title'] as String;
      }
    } else if (data is String && data.isNotEmpty && data.length < 200) {
      message = data;
    }

    message ??= switch (status) {
      401 => 'Phiên đăng nhập đã hết hạn hoặc không hợp lệ.',
      403 => 'Bạn không có quyền thực hiện thao tác này.',
      404 => 'Không tìm thấy dữ liệu.',
      >= 500 => 'Máy chủ gặp lỗi. Vui lòng thử lại sau.',
      _ => 'Yêu cầu không hợp lệ.',
    };
    return ApiException(message, status);
  }
}
