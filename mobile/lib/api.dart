import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client for the desktop ManagerServer. Read-only surface,
/// pairing-code bearer token, short timeouts.
///
/// Server contract:
/// - api/status   -> {ok, business}
/// - api/summary  -> {business, today{...}, week{...}, month{...}, low_stock, ...}
/// - api/sales    -> list
/// - api/products -> list
/// - api/customers-> {customers: [...], suppliers: [...]}
/// - api/top      -> list
/// - api/daily    -> list
class ApiClient {
  ApiClient({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;

  static const Duration _timeout = Duration(seconds: 6);

  Future<dynamic> _call(String path) async {
    final uri = Uri.parse(baseUrl.endsWith('/')
        ? '${baseUrl.substring(0, baseUrl.length - 1)}/$path'
        : '$baseUrl/$path');
    final http.Response res;
    try {
      res = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(_timeout);
    } on TimeoutException {
      throw const ApiError('timeout', 'المحل لا يستجيب');
    } catch (_) {
      throw const ApiError('unreachable', 'تعذّر الاتصال بالخادم');
    }
    if (res.statusCode == 401) {
      throw const ApiError('unauthorized', 'الرمز غير صحيح');
    }
    if (res.statusCode != 200) {
      throw ApiError('server', 'خطأ الخادم (HTTP ${res.statusCode})');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Map<String, dynamic>> status() async =>
      (await _call('api/status')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> summary() async =>
      (await _call('api/summary')) as Map<String, dynamic>;
  Future<List<dynamic>> sales() async => await _call('api/sales') as List<dynamic>;
  Future<List<dynamic>> products(String filter) async =>
      await _call('api/products?filter=$filter') as List<dynamic>;
  Future<Map<String, dynamic>> debts() async =>
      (await _call('api/customers')) as Map<String, dynamic>;
  Future<List<dynamic>> top() async => await _call('api/top') as List<dynamic>;
  Future<List<dynamic>> daily() async => await _call('api/daily') as List<dynamic>;
}

class ApiError implements Exception {
  const ApiError(this.code, this.messageAr, [this.messageFr]);
  final String code;
  final String messageAr;
  final String? messageFr;

  String message(bool ar) =>
      ar ? messageAr : messageFr ?? messageAr;
}
