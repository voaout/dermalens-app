import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'auth_session.dart';

/// Thrown for any non-2xx response or network/parse failure.
class ApiException implements Exception {
  final int statusCode; // 0 = network/timeout/parse error
  final String message;
  final dynamic body;

  ApiException(this.statusCode, this.message, {this.body});

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin HTTP wrapper around [Api] endpoints.
///
/// Injects JSON + JWT headers, applies the timeout, decodes JSON, and turns
/// non-2xx responses into [ApiException]. Use the path constants/functions in
/// api.dart to build calls:
///
/// ```dart
/// final data = await ApiClient.I.get(ProductsApi.search, query: {'q': '토너'});
/// await ApiClient.I.post(ReviewApi.create, body: {'product_id': 1, 'rating': 5});
/// ```
class ApiClient {
  ApiClient._();
  static final ApiClient I = ApiClient._();

  final http.Client _client = http.Client();

  Map<String, String> get _headers => Api.headers(token: AuthSession.token);

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    return _send(() =>
        _client.get(Api.uri(path, query), headers: _headers).timeout(Api.timeout));
  }

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) {
    return _send(() => _client
        .post(Api.uri(path, query), headers: _headers, body: jsonEncode(body))
        .timeout(Api.timeout));
  }

  Future<dynamic> patch(String path, {Object? body, Map<String, dynamic>? query}) {
    return _send(() => _client
        .patch(Api.uri(path, query), headers: _headers, body: jsonEncode(body))
        .timeout(Api.timeout));
  }

  Future<dynamic> delete(String path, {Object? body, Map<String, dynamic>? query}) {
    return _send(() => _client
        .delete(Api.uri(path, query), headers: _headers, body: body == null ? null : jsonEncode(body))
        .timeout(Api.timeout));
  }

  /// Default timeout for multipart uploads — generous, because OCR image
  /// upload + server-side processing easily exceeds the 15s [Api.timeout].
  /// 120s covers slow mobile uploads plus a synchronous OCR round-trip.
  static const Duration _uploadTimeout = Duration(seconds: 120);

  /// Multipart upload (e.g. OCR image). [files] maps a field name to a file path.
  Future<dynamic> upload(
    String path, {
    required Map<String, String> files,
    Map<String, String> fields = const {},
    Duration? timeout,
  }) async {
    final request = http.MultipartRequest('POST', Api.uri(path));
    final token = AuthSession.token;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    for (final entry in files.entries) {
      request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
    }
    final to = timeout ?? _uploadTimeout;
    return _send(() async {
      final streamed = await request.send().timeout(to);
      return http.Response.fromStream(streamed);
    });
  }

  /// 같은 field 이름으로 여러 파일을 한 번에 보내는 multipart 업로드.
  /// 백엔드(Django)는 `request.FILES.getlist('image')`로 리스트를 받습니다.
  Future<dynamic> uploadBytesMulti(
    String path, {
    required String field,
    required List<List<int>> filesBytes,
    List<String>? filenames,
    Map<String, String> fields = const {},
    Duration? timeout,
  }) async {
    final request = http.MultipartRequest('POST', Api.uri(path));
    final token = AuthSession.token;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    for (var i = 0; i < filesBytes.length; i++) {
      final bytes = filesBytes[i];
      if (bytes.isEmpty) continue;
      final name = (filenames != null && i < filenames.length)
          ? filenames[i]
          : 'upload_$i.jpg';
      request.files.add(
        http.MultipartFile.fromBytes(field, bytes, filename: name),
      );
    }
    final to = timeout ?? _uploadTimeout;
    return _send(() async {
      final streamed = await request.send().timeout(to);
      return http.Response.fromStream(streamed);
    });
  }

  /// Multipart upload from in-memory bytes (e.g. image_picker bytes).
  Future<dynamic> uploadBytes(
    String path, {
    required String field,
    required List<int> bytes,
    String filename = 'upload.jpg',
    Map<String, String> fields = const {},
    Duration? timeout,
  }) async {
    final request = http.MultipartRequest('POST', Api.uri(path));
    final token = AuthSession.token;
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    if (bytes.isNotEmpty) {
      request.files
          .add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
    }
    final to = timeout ?? _uploadTimeout;
    return _send(() async {
      final streamed = await request.send().timeout(to);
      return http.Response.fromStream(streamed);
    });
  }

  Future<dynamic> _send(
    Future<http.Response> Function() run, {
    bool allowRefresh = true,
  }) async {
    final http.Response res;
    try {
      res = await run();
    } on SocketException {
      throw ApiException(0, '네트워크에 연결할 수 없어요.');
    } on HttpException {
      throw ApiException(0, '요청을 처리하지 못했어요.');
    } catch (e) {
      throw ApiException(0, '요청 중 오류가 발생했어요: $e');
    }

    final decoded = _decode(res);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // The API uses { "success": false, "message": ... } for handled errors.
      if (decoded is Map && decoded['success'] == false) {
        throw ApiException(
          res.statusCode,
          _errorMessage(decoded, res.statusCode),
          body: decoded,
        );
      }
      return decoded;
    }

    // Access token expired → try refreshing once, then retry the request.
    if (res.statusCode == 401 && allowRefresh && await _tryRefresh()) {
      return _send(run, allowRefresh: false);
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      AuthSession.clear();
    }

    // Surface debug info in the console for any non-2xx so URL/route
    // mismatches (e.g. 404 from "endpoint not deployed") are easy to diagnose.
    if (kDebugMode) {
      debugPrint(
        '[API ${res.statusCode}] ${res.request?.method} ${res.request?.url}\n'
        '  body: ${res.body.length > 500 ? '${res.body.substring(0, 500)}…' : res.body}',
      );
    }

    final friendlyMsg = _errorMessage(decoded, res.statusCode);
    final pathHint = res.statusCode == 404
        ? ' (${res.request?.url.path ?? ''})'
        : '';
    throw ApiException(
      res.statusCode,
      '$friendlyMsg$pathHint',
      body: decoded,
    );
  }

  /// Refreshes the access token using the stored refresh token.
  /// Returns true if a new access token was obtained.
  Future<bool> _tryRefresh() async {
    final refresh = AuthSession.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _client
          .post(
            Api.uri(UsersApi.tokenRefresh),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(Api.timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map && data['access'] is String) {
          AuthSession.token = data['access'] as String;
          if (data['refresh'] is String) {
            AuthSession.refreshToken = data['refresh'] as String;
          }
          return true;
        }
      }
    } catch (_) {
      // fall through
    }
    return false;
  }

  dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return res.body; // non-JSON payload
    }
  }

  String _errorMessage(dynamic body, int status) {
    if (body is Map) {
      for (final key in ['message', 'detail', 'error']) {
        final v = body[key];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return '요청에 실패했어요. (HTTP $status)';
  }
}
