import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dz_business_pro/core/money.dart';
import 'package:dz_business_pro/data/database/app_database.dart';
import 'package:dz_business_pro/remote/manager_server.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = createDatabaseFactoryFfi(ffiInit: () {
      open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    });
  });

  late Directory tmp;
  late AppDatabase database;
  late ManagerServer server;
  late int port;
  late String code;

  Future<void> seedSale() async {
    final now = Dates.iso(DateTime.now());
    await database.db.insert('products', {
      'name_ar': 'قنينة', 'name_fr': 'Bouteille', 'sku': 'SKU-1',
      'cost_c': 1000, 'price_c': 1500, 'stock_qty': 40, 'min_stock': 5,
      'created_at': now, 'updated_at': now,
    });
    await database.db.insert('sales', {
      'invoice_no': 'INV-1', 'sale_at': now,
      'subtotal_c': 15000, 'total_c': 15000, 'paid_c': 15000,
      'status': 'completed', 'payment_method': 'cash',
    });
  }

  Future<Map<String, dynamic>> call(String path, {String? token}) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/$path'))
        ..headers.set('authorization', 'Bearer ${token ?? code}');
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      return {'status': res.statusCode, 'body': jsonDecode(body) as Object?};
    } finally {
      client.close();
    }
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dzbp_srv_test');
    if (AppDatabase.instance.isOpen) await AppDatabase.instance.close();
    database = AppDatabase.instance;
    await database.open('${tmp.path}/server_test.db');
    await seedSale();
    server = ManagerServer(database);
    code = await server.start(port: 0, addr: InternetAddress.loopbackIPv4);
    port = server.running!.port;
  });

  tearDown(() async {
    await server.stop();
    await AppDatabase.instance.close();
    tmp.deleteSync(recursive: true);
  });

  test('start generates a 6-digit pairing code and serves status', () async {
    expect(code, matches(RegExp(r'^\d{6}$')));
    final r = await call('api/status');
    expect(r['status'], 200);
    expect((r['body'] as Map)['ok'], true);
  });

  test('rejects wrong token with 401', () async {
    final r = await call('api/summary', token: '000000');
    expect(r['status'], 401);
  });

  test('summary exposes real KPI windows and stock counters', () async {
    final r = await call('api/summary');
    final body = r['body'] as Map;
    final today = body['today'] as Map;
    expect(today['revenue_c'], 15000);
    expect(today['count'], 1);
    expect(body['low_stock'], 0);
    expect(r['status'], 200);
  });

  test('sales, products, debts, top and daily endpoints respond', () async {
    for (final p in ['api/sales', 'api/products', 'api/customers', 'api/top', 'api/daily']) {
      final r = await call(p);
      expect(r['status'], 200, reason: p);
      expect(r['body'], isNotNull, reason: p);
    }
    final prods = (await call('api/products?filter=low'))['body'] as List;
    expect(prods, isEmpty);
  });

  test('unknown paths and non-API paths are rejected quietly', () async {
    expect((await call('api/secret'))['status'], 404);
    final root = await HttpClient().getUrl(Uri.parse('http://127.0.0.1:$port/'));
    final res = await root.close();
    expect(res.statusCode, 404);
  });

  test('stop releases the port', () async {
    await server.stop();
    expect(server.running, isNull);
  });
}
