import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:sqflite_common/utils/utils.dart';

import '../data/database/app_database.dart';
import '../core/money.dart' show Dates;

/// Read-only HTTP API so the manager's phone app can follow the business
/// live, over the shop's local Wi-Fi network only.
///
/// Security model
/// --------------
/// - Endpoint surface is strictly read-only: no POST/PUT/DELETE route exists.
/// - Every /api/* request must carry the pairing code as
///   `Authorization: Bearer <code>` (or ?token=). The code is 6 random digits
///   regenerated at each server start.
/// - Wrong token: 401. Nothing else is reachable; there is no CORS wildcard
///   for mutating verbs because no mutating verb exists.
///
/// All amounts travel as integer centimes exactly as stored in SQLite.
class ManagerServer {
  ManagerServer(this.db);

  final AppDatabase db;

  HttpServer? _server;
  HttpServer? get running => _server;
  String code = '';
  String businessName = '';
  int port = 8090;

  /// Optional address reachable from outside the shop LAN (e.g. a Tailscale
  /// or forwarded host). Shown/displayed in the QR as a second candidate URL.
  String externalHost = '';

  String? _boundHost;
  String? get host => _boundHost;

  /// Starts listening on the LAN interface(s) (or [addr] for tests, typically
  /// loopback). Returns the 6-digit pairing code.
  Future<String> start({int port = 8090, InternetAddress? addr}) async {
    if (_server != null) {
      throw StateError('alreadyRunning');
    }
    final rnd = Random.secure();
    code = List.generate(6, (_) => rnd.nextInt(10)).join();
    this.port = port;
    final server = await io.serve(
      _pipeline,
      addr ?? InternetAddress.anyIPv4,
      port,
    );
    _server = server;
    try {
      businessName = await _businessName();
    } catch (_) {
      businessName = '';
    }
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      _boundHost = ifs
          .where((i) => !i.addresses.first.isLoopback)
          .map((i) => i.addresses.first.address)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => '127.0.0.1');
    } catch (_) {
      _boundHost = '127.0.0.1';
    }
    return code;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _boundHost = null;
  }

  Handler get _pipeline => const Pipeline()
      .addMiddleware(_cors)
      .addHandler(_router);

  Middleware get _cors => (inner) => (req) async {
        final res = await inner(req);
        return res.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'Authorization',
        });
      };

  Handler get _router => (Request req) async {
        final path = req.url.path;
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: _headers);
        }
        if (!path.startsWith('api/')) {
          return Response(404, body: '{"error":"notFound"}', headers: _headers);
        }
        final token = req.headers['authorization']?.replaceFirst('Bearer ', '') ??
            req.url.queryParameters['token'] ??
            '';
        if (token != code) {
          return Response(401, body: '{"error":"unauthorized"}', headers: _headers);
        }
        switch (path) {
          case 'api/status':
            return _json({'ok': true, 'business': await _businessName()});
          case 'api/summary':
            return _json(await _summary());
          case 'api/sales':
            return _json(await _sales());
          case 'api/products':
            return _json(await _products(req.url.queryParameters['filter'] ?? 'all'));
          case 'api/customers':
            return _json(await _debts());
          case 'api/top':
            return _json(await _top());
          case 'api/daily':
            return _json(await _daily());
          default:
            return Response(404, body: '{"error":"notFound"}', headers: _headers);
        }
      };

  Map<String, String> get _headers =>
      {'content-type': 'application/json; charset=utf-8'};

  Response _json(Object data) =>
      Response.ok(jsonEncode(data), headers: _headers);

  Future<String> _businessName() async {
    final rows = await db.db.query('business_profile', limit: 1);
    if (rows.isEmpty) return '';
    final r = rows.first;
    return (r['name_ar'] as String? ?? '').isNotEmpty &&
            (r['name_fr'] as String? ?? '').isEmpty
        ? r['name_ar'] as String
        : r['name_fr'] as String? ?? r['name_ar'] as String? ?? '';
  }

  int _one(Map<String, Object?> row, String col) =>
      row[col] is int ? row[col] as int : (row[col] as num? ?? 0).toInt();

  Future<Map<String, Object?>> _window(String from, String to) async {
    final revenue = firstIntValue(await db.db.rawQuery(
        "SELECT COALESCE(SUM(total_c),0) v FROM sales WHERE status='completed' AND sale_at >= ? AND sale_at <= ?",
        [from, to])) ?? 0;
    final count = firstIntValue(await db.db.rawQuery(
        "SELECT COUNT(*) v FROM sales WHERE status='completed' AND sale_at >= ? AND sale_at <= ?",
        [from, to])) ?? 0;
    final gross = firstIntValue(await db.db.rawQuery('''
      SELECT COALESCE(SUM(si.total_c - si.unit_cost_c * si.qty),0) v
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status='completed' AND s.sale_at >= ? AND s.sale_at <= ?
    ''', [from, to])) ?? 0;
    final returns = firstIntValue(await db.db.rawQuery(
        'SELECT COALESCE(SUM(total_c),0) v FROM returns WHERE return_at >= ? AND return_at <= ?',
        [from, to])) ?? 0;
    final expenses = firstIntValue(await db.db.rawQuery(
        'SELECT COALESCE(SUM(amount_c),0) v FROM expenses WHERE paid_at >= ? AND paid_at <= ?',
        [from, to])) ?? 0;
    final grossNet = gross - returns;
    return {
      'from': from,
      'to': to,
      'revenue_c': revenue,
      'count': count,
      'gross_c': grossNet,
      'expenses_c': expenses,
      'net_c': grossNet - expenses,
    };
  }

  String get _dayStart => "${Dates.iso(DateTime.now()).substring(0, 10)}T00:00:00";

  String _daysAgo(int days) =>
      DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();

  Future<Map<String, Object?>> _summary() async {
    final now = Dates.iso(DateTime.now());
    return {
      'business': await _businessName(),
      'today': await _window(_dayStart, now),
      'week': await _window(_daysAgo(7), now),
      'month': await _window(_daysAgo(30), now),
      'low_stock': await _lowStockCount(),
      'out_of_stock': firstIntValue(await db.db.rawQuery(
          "SELECT COUNT(*) v FROM products WHERE archived=0 AND stock_qty <= 0")) ?? 0,
      'customer_debt_c': firstIntValue(await db.db.rawQuery(
          'SELECT COALESCE(SUM(MAX(balance_c,0)),0) v FROM customers WHERE active=1')) ?? 0,
      'supplier_debt_c': firstIntValue(await db.db.rawQuery(
          'SELECT COALESCE(SUM(MAX(total_c - paid_c,0)),0) v FROM purchases WHERE status=\'confirmed\'')) ?? 0,
      'due_checks': firstIntValue(await db.db.rawQuery(
          "SELECT COUNT(*) v FROM checks WHERE status='pending' AND due_date <= ?",
          [now.substring(0, 10)])) ?? 0,
    };
  }

  Future<int> _lowStockCount() async =>
      firstIntValue(await db.db.rawQuery('''
      SELECT COUNT(*) v FROM products
      WHERE archived=0 AND stock_qty <= min_stock''')) ?? 0;

  Future<List<Map<String, Object?>>> _sales() async {
    final rows = await db.db.rawQuery('''
      SELECT s.id, s.invoice_no, s.sale_at, s.total_c, s.paid_c, s.status,
             s.payment_method, COALESCE(c.name_fr,'') AS customer
      FROM sales s LEFT JOIN customers c ON c.id = s.customer_id
      ORDER BY s.id DESC LIMIT 60
    ''');
    return [
      for (final r in rows) {
        'id': r['id'], 'invoice_no': r['invoice_no'], 'at': r['sale_at'],
        'total_c': _one(r, 'total_c'), 'paid_c': _one(r, 'paid_c'),
        'status': r['status'], 'method': r['payment_method'],
        'customer': r['customer'],
      }
    ];
  }

  Future<List<Map<String, Object?>>> _products(String filter) async {
    final where = switch (filter) {
      'low' => 'archived=0 AND stock_qty <= min_stock',
      'out' => 'archived=0 AND stock_qty <= 0',
      _ => 'archived=0',
    };
    final rows = await db.db.rawQuery(
        'SELECT id, name_ar, name_fr, sku, stock_qty, min_stock, price_c, wholesale_c '
        'FROM products WHERE $where ORDER BY stock_qty ASC LIMIT 300');
    return [
      for (final r in rows) {
        'id': r['id'], 'name_ar': r['name_ar'], 'name_fr': r['name_fr'],
        'sku': r['sku'], 'stock': _one(r, 'stock_qty'),
        'min': _one(r, 'min_stock'), 'price_c': _one(r, 'price_c'),
        'wholesale_c': _one(r, 'wholesale_c'),
      }
    ];
  }

  Future<Map<String, Object?>> _debts() async {
    final cRows = await db.db.rawQuery(
        'SELECT id, name_ar, name_fr, phone, balance_c FROM customers '
        'WHERE active=1 AND balance_c > 0 ORDER BY balance_c DESC LIMIT 200');
    final sRows = await db.db.rawQuery('''
      SELECT su.id, su.name_fr, su.name_ar,
             COALESCE(SUM(MAX(p.total_c - p.paid_c,0)),0) v
      FROM purchases p JOIN suppliers su ON su.id = p.supplier_id
      WHERE p.status='confirmed' GROUP BY su.id HAVING v > 0 ORDER BY v DESC LIMIT 100
    ''');
    return {
      'customers': [
        for (final r in cRows) {
          'id': r['id'], 'name_ar': r['name_ar'], 'name_fr': r['name_fr'],
          'phone': r['phone'], 'debt_c': _one(r, 'balance_c'),
        }
      ],
      'suppliers': [
        for (final r in sRows) {
          'id': r['id'], 'name_ar': r['name_ar'], 'name_fr': r['name_fr'],
          'debt_c': _one(r, 'v'),
        }
      ],
    };
  }

  Future<List<Map<String, Object?>>> _top() async {
    final from = _daysAgo(30);
    final rows = await db.db.rawQuery('''
      SELECT si.name_fr AS n, si.name_ar AS na,
             COALESCE(SUM(si.qty - si.returned_qty),0) q,
             COALESCE(SUM(si.total_c - si.unit_cost_c * si.qty),0) p
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status='completed' AND s.sale_at >= ?
      GROUP BY si.name_fr ORDER BY q DESC LIMIT 10
    ''', [from]);
    return [
      for (final r in rows) {
        'name_fr': r['n'], 'name_ar': r['na'],
        'qty': _one(r, 'q'), 'profit_c': _one(r, 'p'),
      }
    ];
  }

  Future<List<Map<String, Object?>>> _daily() async {
    final rows = await db.db.rawQuery(
        "SELECT substr(sale_at,1,10) d, SUM(total_c) v, COUNT(*) c "
        "FROM sales WHERE status='completed' AND sale_at >= ? GROUP BY d ORDER BY d",
        [Dates.iso(DateTime.now().subtract(const Duration(days: 13)))]);
    return [for (final r in rows) {'day': r['d'], 'revenue_c': _one(r, 'v'), 'count': _one(r, 'c')}];
  }
}
