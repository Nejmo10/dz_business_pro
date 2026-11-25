import 'dart:convert';

/// Decoded pairing payload from the desktop "Manager's phone" QR / clipboard.
///
/// New format (v1):
/// `{"v":1,"n":"اسم المحل","token":"123456","urls":["http://192.168.1.10:8090","http://100.64.0.7:8090"]}`
/// Legacy format: `{"url":"http://...","token":"123456"}` — or a bare token.
class PairLink {
  const PairLink({required this.hosts, required this.token, this.business = ''});

  /// Candidate `host:port` addresses, first match wins (LAN first, then the
  /// external/home address).
  final List<String> hosts;
  final String token;

  /// Display name of the business carried in the QR (may be empty).
  final String business;

  static String? _cleanHost(Object? raw) {
    var s = raw?.toString().trim() ?? '';
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    s = s.split('/').first;
    if (s.isEmpty || !s.contains(':')) return null;
    return s;
  }

  static bool _isToken(Object? v) =>
      RegExp(r'^\d{6}$').hasMatch(v?.toString() ?? '');

  static PairLink? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (!text.startsWith('{')) {
      return _isToken(text) ? PairLink(hosts: [], token: text) : null;
    }
    try {
      final Object? decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return null;
      if (!_isToken(decoded['token'])) return null;
      final urls = <String>[
        if (decoded['urls'] is List)
          for (final u in decoded['urls'] as List)
            if (_cleanHost(u) != null) _cleanHost(u)!,
        if (_cleanHost(decoded['url']) != null) _cleanHost(decoded['url'])!,
      ];
      return PairLink(
        hosts: urls.toSet().toList(),
        token: decoded['token'] as String,
        business: decoded['n']?.toString() ?? '',
      );
    } on FormatException catch (_) {
      return null;
    } on TypeError catch (_) {
      return null;
    }
  }
}
