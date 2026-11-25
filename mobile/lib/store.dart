import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'l10n.dart';

/// Persisted pairing {baseUrl, token} so the app reconnects automatically.
class Store {
  static const _kHost = 'host';
  static const _kToken = 'token';
  static const _kArabic = 'arabic';

  static String? host;
  static String? token;

  static Future<bool> load() async {
    final sp = await SharedPreferences.getInstance();
    host = sp.getString(_kHost);
    token = sp.getString(_kToken);
    gAr = sp.getBool(_kArabic) ?? true;
    return host != null && token != null;
  }

  static Future<void> save(String host_, String token_) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kHost, host_);
    await sp.setString(_kToken, token_);
    host = host_;
    token = token_;
  }

  static Future<void> saveLanguage(bool ar) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kArabic, ar);
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kHost);
    await sp.remove(_kToken);
    host = null;
    token = null;
  }

  static ApiClient client() => ApiClient(baseUrl: 'http://$host', token: token ?? '');
}
