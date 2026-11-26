import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dz_business_pro/data/database/app_database.dart';
import 'package:dz_business_pro/data/models/models.dart';
import 'package:dz_business_pro/data/repositories/repositories.dart';

/// Regression tests for the document counters (sale/purchase/return).
///
/// Reported bug: the second purchase failed with a bare error because the
/// counter was only UPDATEd (never inserted), so databases without the
/// seeded `purchase_counter` row reused `B-00001` forever and hit the
/// UNIQUE(invoice_no) constraint on the second purchase.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = createDatabaseFactoryFfi(ffiInit: () {
      open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    });
  });

  late Directory tmp;
  late AppDatabase database;
  late PurchasesRepo purchases;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dzbp_ctr_test');
    if (AppDatabase.instance.isOpen) await AppDatabase.instance.close();
    database = AppDatabase.instance;
    await database.open('${tmp.path}/counter_test.db');
    purchases = PurchasesRepo(database, InventoryRepo(database), SettingsRepo(database));
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    tmp.deleteSync(recursive: true);
  });

  PurchaseItem item(int productId) => PurchaseItem(
      productId: productId, qty: 2, unitCostC: 5000, totalC: 10000,
      nameAr: 'صابون', nameFr: 'Savon');

  test('two purchases in a row succeed with unique numbers even when the counter row is missing', () async {
    // Simulate a legacy database without the seeded counters.
    await database.db.delete('app_settings', where: "key LIKE '%_counter'");
    final sid = await purchases.saveSupplier(Supplier(nameAr: 'المورد الأول'));
    final p1 = await purchases.saveProduct(Product(
        nameAr: 'صابون', nameFr: 'Savon', sku: 'P-1', costC: 5000, priceC: 6000));
    final p2 = await purchases.saveProduct(Product(
        nameAr: 'سكر', nameFr: 'Sucre', sku: 'P-2', costC: 7000, priceC: 8000));

    final id1 = await purchases.createPurchase(
        supplierId: sid, items: [item(p1)],
        discountC: 0, extraCostsC: 0, paidC: 10000, taxEnabled: false, taxRate: 0);
    final id2 = await purchases.createPurchase(
        supplierId: sid, items: [item(p2)],
        discountC: 0, extraCostsC: 0, paidC: 10000, taxEnabled: false, taxRate: 0);

    expect(id2, isNot(id1));
    final nos = [
      for (final r in await database.db.query('purchases', columns: ['invoice_no']))
        r['invoice_no'] as String,
    ];
    expect(nos, ['B-00001', 'B-00002'], reason: 'unique ascending numbers, got $nos');
  });

  test('counter never rewinds below invoices that already exist', () async {
    await database.db.delete('app_settings', where: "key = 'purchase_counter'");
    final now = '2026-01-01T10:00:00';
    await database.db.insert('purchases', {
      'invoice_no': 'B-00007', 'supplier_id': null, 'purchase_at': now,
      'subtotal_c': 100, 'discount_c': 0, 'tax_c': 0, 'extra_costs_c': 0,
      'total_c': 100, 'paid_c': 0, 'status': 'confirmed', 'notes': '',
    });
    final sid = await purchases.saveSupplier(Supplier(nameAr: 'مورد'));
    final p1 = await purchases.saveProduct(Product(
        nameAr: 'زيت', nameFr: 'Huile', sku: 'P-3', costC: 5000, priceC: 6000));

    await purchases.createPurchase(
        supplierId: sid, items: [item(p1)],
        discountC: 0, extraCostsC: 0, paidC: 0, taxEnabled: false, taxRate: 0);

    final nos = [
      for (final r in await database.db.query('purchases', orderBy: 'id', columns: ['invoice_no']))
        r['invoice_no'] as String,
    ];
    expect(nos.last, 'B-00008', reason: 'must continue after B-00007, got $nos');
  });
}
