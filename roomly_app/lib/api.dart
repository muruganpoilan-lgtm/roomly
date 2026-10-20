import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

class ApiResult {
  final bool ok;
  final int status;
  final dynamic data;
  final String error;

  const ApiResult._(this.ok, this.status, this.data, this.error);
  factory ApiResult.success(int status, dynamic data) => ApiResult._(true, status, data, '');
  factory ApiResult.failure(int status, String error) => ApiResult._(false, status, null, error);
}

// One place for every call to the Roomly API. Never throws: you always get an ApiResult.
class Api {
  static String? token;
  static void Function()? onUnauthorized;

  static Future<ApiResult> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);

  static Future<ApiResult> post(String path, {Object? body}) => _send('POST', path, body: body);

  static Future<ApiResult> put(String path, {Object? body}) => _send('PUT', path, body: body);

  static Future<ApiResult> patch(String path, {Object? body}) => _send('PATCH', path, body: body);

  static Future<ApiResult> delete(String path) => _send('DELETE', path);

  // Upload photos. Each entry is (file name, file bytes). The server reads the field called "files".
  static Future<ApiResult> uploadFiles(String path, List<MapEntry<String, List<int>>> files) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBase$path'));
    final t = token;
    if (t != null) req.headers['Authorization'] = 'Bearer $t';
    for (final f in files) {
      req.files.add(http.MultipartFile.fromBytes('files', f.value, filename: f.key));
    }
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 120));
      final res = await http.Response.fromStream(streamed);
      return _finish(res);
    } catch (_) {
      return ApiResult.failure(0, "Can't reach the Roomly server. Check that the backend is running and the address in config.dart is right.");
    }
  }

  static Future<ApiResult> _send(String method, String path, {Map<String, String>? query, Object? body}) async {
    var uri = Uri.parse('$apiBase$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final headers = <String, String>{};
    if (body != null) headers['Content-Type'] = 'application/json';
    final t = token;
    if (t != null) headers['Authorization'] = 'Bearer $t';

    try {
      http.Response res;
      const wait = Duration(seconds: 20);
      final encoded = body == null ? null : jsonEncode(body);
      if (method == 'GET') {
        res = await http.get(uri, headers: headers).timeout(wait);
      } else if (method == 'PUT') {
        res = await http.put(uri, headers: headers, body: encoded).timeout(wait);
      } else if (method == 'PATCH') {
        res = await http.patch(uri, headers: headers, body: encoded).timeout(wait);
      } else if (method == 'DELETE') {
        res = await http.delete(uri, headers: headers).timeout(wait);
      } else {
        res = await http.post(uri, headers: headers, body: encoded).timeout(wait);
      }
      return _finish(res);
    } catch (_) {
      return ApiResult.failure(
        0,
        "Can't reach the Roomly server. Check that the backend is running and the address in config.dart is right.",
      );
    }
  }

  static ApiResult _finish(http.Response res) {
    dynamic data;
    try {
      data = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ApiResult.success(res.statusCode, data);
    }
    if (res.statusCode == 401) {
      final cb = onUnauthorized;
      if (cb != null) cb();
    }
    return ApiResult.failure(res.statusCode, _message(data));
  }

  // FastAPI sends {"detail": "text"} or, for bad input, {"detail": [{"loc": [...], "msg": "..."}]}.
  static String _message(dynamic data) {
    const fallback = 'Something went wrong. Try again.';
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty && d.first is Map) {
        final first = d.first as Map;
        final msg = (first['msg'] ?? '').toString().replaceFirst('Value error, ', '');
        final loc = first['loc'];
        if (loc is List && loc.isNotEmpty && loc.last.toString() != 'body') {
          return '${loc.last}: $msg';
        }
        if (msg.isNotEmpty) return msg;
      }
    }
    return fallback;
  }
}
