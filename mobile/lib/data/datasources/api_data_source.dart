import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'local_data_source.dart';

class ApiDataSource {
  final LocalDataSource _local;
  late final Dio _dio;
  // Persistent HTTP client reused across all streaming calls.
  // Avoids a new TCP+TLS handshake (200–500 ms on mobile) per generation.
  final _streamClient = http.Client();

  ApiDataSource(this._local) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    // Inject JWT on every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _local.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(
      String username, String password, String deviceId) async {
    final res = await _dio.post(ApiConstants.login, data: {
      'username': username,
      'password': password,
      'device_id': deviceId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get(ApiConstants.me);
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout(String deviceId) async {
    try {
      await _dio.post(ApiConstants.logout, data: {'device_id': deviceId});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> verifySubscription(
      String purchaseToken, String productId) async {
    final res = await _dio.post(ApiConstants.verifySubscription, data: {
      'purchase_token': purchaseToken,
      'product_id': productId,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Streaming AI responses ────────────────────────────────────────────────
  // Uses http package (not Dio) for chunked streaming

  Stream<String> streamPost(String endpoint, Map<String, dynamic> body) async* {
    final token = await _local.getToken();
    final request = http.Request(
      'POST',
      Uri.parse('${ApiConstants.baseUrl}$endpoint'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/plain';
    // Disable compression: dart:io's HttpClient sends Accept-Encoding: gzip by
    // default. If any proxy between the app and server honours this, the entire
    // response would be buffered for compression, breaking chunked streaming.
    request.headers['Accept-Encoding'] = 'identity';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.body = jsonEncode(body);

    try {
      final streamedResponse = await _streamClient.send(request);
      if (streamedResponse.statusCode == 401) {
        throw Exception('未登录，请重新登录');
      }
      if (streamedResponse.statusCode == 403) {
        throw Exception('账号无权限访问此功能');
      }
      if (streamedResponse.statusCode == 429) {
        // Quota exceeded — parse JSON error body
        final body = await streamedResponse.stream.bytesToString();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        throw Exception(decoded['error'] ?? '今日使用次数已达上限');
      }
      if (streamedResponse.statusCode != 200) {
        throw Exception('服务器错误 (${streamedResponse.statusCode})');
      }
      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        yield chunk;
      }
    } catch (e) {
      rethrow;
    }
  }

  void dispose() {
    _streamClient.close();
  }

  // ── Non-streaming (search, fetch-url) ────────────────────────────────────

  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    final res = await _dio.post(endpoint, data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, dynamic>? params}) async {
    final res = await _dio.get(endpoint, queryParameters: params);
    return res.data as Map<String, dynamic>;
  }
}
