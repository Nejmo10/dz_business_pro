import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dz_business_pro/data/database/app_database.dart';
import 'package:dz_business_pro/data/models/models.dart';
import 'package:dz_business_pro/data/repositories/repositories.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = createDatabaseFactoryFfi(ffiInit: () {
      open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
    });
  });

  late Directory tmp;
  late AppDatabase database;

  Future<AppDatabase> freshDb() async {
    if (AppDatabase.instance.isOpen) await AppDatabase.instance.close();
    final db = AppDatabase.instance;
    await db.open('${tmp.path}/test_${DateTime.now().microsecondsSinceEpoch}.db');
    return db;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dzbp_test');
    database = await freshDb();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    tmp.deleteSync(recursive: true);
  });

  test('schema: all 22 tables exist, integrity ok', () async {
    final tables = await database.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
    final names = tables.map((r) => r['name']).toSet();
    for (final t in [
      'app_settings', 'business_profile', 'users', 'categories', 'brands', 'products',
      'customers', 'suppliers', 'sales', 'sale_items', 'purchases', 'purchase_items',
      'invoices', 'payments', 'expenses', 'expense_categories', 'stock_movements',
      'cash_registers', 'cash_movements', 'returns', 'return_items', 'audit_logs',
    ]) {
      expect(names.contains(t), true, reason: 'missing table $t');
    }
    expect(await database.integrityCheck(), true);
  });

  test('computeTotals: discount then tax, integer safe, clamped', () {
    final t1 = computeTotals(subtotalC: 12500, discountC: 500, taxEnabled: false, taxRate: 0);
    expect(t1.totalC, 12000);
    final t2 = computeTotals(subtotalC: 12500, discountC: 500, taxEnabled: true, taxRate: 19);
    expect(t2.taxC, 2280);
    expect(t2.totalC, 12000 + 2280);
    final t3 = computeTotals(subtotalC: 100, discountC: 500, taxEnabled: false, taxRate: 0);
    expect(t3.totalC, 0);
    expect(t3.taxC, 0);
  });

  test('product CRUD records a stock movement for every stock change', () async {
    final db = EnvRepo<AppDatabase>(database);
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);

    final catId = await catalog.addCategory('فئة', 'Categorie');
    final id = await catalog.saveProduct(Product(
        nameAr: 'منتج', nameFr: 'Produit', sku: 'SKU1', barcode: '123',
        categoryId: catId, costC: 500, priceC: 800, wholesaleC: 700, stockQty: 10,
        minStock: 2));
    final created = (await catalog.productById(id))!;
    expect(created.stockQty, 10);

    final moves1 = await inventory.movements();
    expect(moves1.length, 1);
    expect(moves1.first.type, 'in');
    expect(moves1.first.balanceAfter, 10);

    await catalog.saveProduct(Product(
        id: id, nameAr: 'منتج', nameFr: 'Produit', sku: 'SKU1', barcode: '123',
        categoryId: catId, costC: 500, priceC: 800, wholesaleC: 700, stockQty: 25));
    final updated = (await catalog.productById(id))!;
    expect(updated.stockQty, 25);
    final moves2 = await inventory.movements();
    expect(moves2.length, 2);
    expect(moves2.first.type, 'in');
    expect(moves2.first.balanceAfter, 25);

    await inventory.applyManualMove(productId: id, type: 'out', qty: 5, note: 'test out');
    final afterOut = (await catalog.productById(id))!;
    expect(afterOut.stockQty, 20);
    expect(await db.count('stock_movements'), 3);
  });

  test('sale totals, stock, payments, customer debt — full flow', () async {
    final db = EnvRepo<AppDatabase>(database);
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);
    final people = PeopleRepo(database, inventory);
    final sales = SalesRepo(database, inventory, SettingsRepo(database));

    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Stylo', nameAr: 'قلم', costC: 50000, priceC: 80000, stockQty: 10));
    final custId = await people.saveCustomer(Customer(nameFr: 'Client', nameAr: 'عميل'));

    final saleId = await sales.createSale(
      customerId: custId,
      items: [SaleItem(
          productId: prodId, nameFr: 'Stylo', qty: 3,
          unitPriceC: 80000, unitCostC: 50000, totalC: 240000)],
      discountC: 40000,
      paymentMethod: 'partial',
      paidC: 100000,
      taxEnabled: false,
      taxRate: 0,
    );

    final sale = (await sales.sales()).firstWhere((s) => s.id == saleId);
    expect(sale.subtotalC, 240000);
    expect(sale.discountC, 40000);
    expect(sale.totalC, 200000);
    expect(sale.paidC, 100000);
    expect(sale.status, 'completed');
    expect(sale.invoiceNo.isNotEmpty, true);

    final items = await sales.saleItems(saleId);
    expect(items.first.qty, 3);
    expect(items.first.totalC, 240000);
    expect(items.first.unitCostC, 50000);

    final prod = (await catalog.productById(prodId))!;
    expect(prod.stockQty, 7);

    final outMove = (await inventory.movements())
        .where((m) => m.productId == prodId && m.type == 'out').toList();
    expect(outMove.length, 1);
    expect(outMove.first.balanceAfter, 7);
    expect(outMove.first.refType, 'sale');

    final cust = (await people.customerById(custId))!;
    expect(cust.balanceC, 100000);

    final pays = await people.payments(direction: 'sale', partyId: custId);
    expect(pays.length, 1);
    expect(pays.first.amountC, 100000);

    await people.recordPayment(
        direction: 'sale', refId: saleId, partyId: custId,
        amountC: 60000, method: 'cash');
    final cust2 = (await people.customerById(custId))!;
    expect(cust2.balanceC, 40000);
    expect(await db.count('payments'), 2);
  });

  test('insufficient stock: sale is fully rolled back', () async {
    final db = EnvRepo<AppDatabase>(database);
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);
    final settings = SettingsRepo(database);
    final sales = SalesRepo(database, inventory, settings);

    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Cahier', nameAr: 'دفتر', costC: 10000, priceC: 20000, stockQty: 2));

    await expectLater(
      sales.createSale(
        items: [SaleItem(
            productId: prodId, nameFr: 'Cahier', qty: 100,
            unitPriceC: 20000, unitCostC: 10000, totalC: 2000000)],
        discountC: 0,
        paymentMethod: 'cash',
        paidC: 2000000,
        taxEnabled: false,
        taxRate: 0,
      ),
      throwsA(isA<AppException>()),
    );

    expect(await db.count('sales'), 0);
    expect(await db.count('sale_items'), 0);
    expect(await db.count('payments'), 0);
    expect(await db.count('stock_movements'), 1);
    expect(await db.count('invoices'), 0);
    expect((await catalog.productById(prodId))!.stockQty, 2);
    final counter = await settings.get('sale_counter');
    expect(counter == '' || counter == '0', true, reason: 'sale counter must roll back');
  });

  test('credit sale keeps due and customer balance consistent', () async {
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);
    final people = PeopleRepo(database, inventory);
    final sales = SalesRepo(database, inventory, SettingsRepo(database));

    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Sac', nameAr: 'حقيبة', costC: 100000, priceC: 150000, stockQty: 5));
    final custId = await people.saveCustomer(
        Customer(nameFr: 'Client2', nameAr: 'عميل2', creditLimitC: 500000));

    final saleId = await sales.createSale(
      customerId: custId,
      items: [SaleItem(
          productId: prodId, nameFr: 'Sac', qty: 2,
          unitPriceC: 150000, unitCostC: 100000, totalC: 300000)],
      discountC: 0,
      paymentMethod: 'credit',
      paidC: 0,
      taxEnabled: false,
      taxRate: 0,
    );
    final sale = (await sales.sales()).firstWhere((s) => s.id == saleId);
    expect(sale.paidC, 0);
    expect(sale.totalC, 300000);

    expect((await people.customerById(custId))!.balanceC, 300000);
    expect((await people.payments(direction: 'sale', partyId: custId)).length, 0);

    await people.recordPayment(
        direction: 'sale', refId: saleId, partyId: custId,
        amountC: 300000, method: 'cash');
    expect((await people.customerById(custId))!.balanceC, 0);
  });

  test('purchase: stock in, supplier payable, payment reduces debt', () async {
    final db = EnvRepo<AppDatabase>(database);
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);
    final people = PeopleRepo(database, inventory);
    final purchases = PurchasesRepo(database, inventory, SettingsRepo(database));

    final supId = await people.saveSupplier(
        Supplier(nameFr: 'Fournisseur', nameAr: 'مزود', phone: '0500'));
    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Ecran', nameAr: 'شاشة', costC: 900000, priceC: 1200000, stockQty: 1));

    final purId = await purchases.createPurchase(
      supplierId: supId,
      items: [PurchaseItem(productId: prodId, qty: 4, unitCostC: 900000, totalC: 3600000)],
      discountC: 0,
      extraCostsC: 0,
      paidC: 1000000,
      taxEnabled: false,
      taxRate: 0,
      updateCostPrices: false,
    );

    expect((await catalog.productById(prodId))!.stockQty, 5);
    expect((await people.supplierById(supId))!.balanceC, 2600000);

    await people.recordPayment(
        direction: 'purchase', refId: purId, partyId: supId,
        amountC: 600000, method: 'cash');
    expect((await people.supplierById(supId))!.balanceC, 2000000);

    expect((await inventory.movements()).where((m) => m.refType == 'purchase').length, 1);
    expect(await db.count('purchases'), 1);
    expect(await db.count('purchase_items'), 1);
  });

  test('purchase with tax and extra costs', () async {
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);
    final people = PeopleRepo(database, inventory);
    final purchases = PurchasesRepo(database, inventory, SettingsRepo(database));

    final supId = await people.saveSupplier(Supplier(nameFr: 'F2', nameAr: 'ف2'));
    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Ecran2', nameAr: 'شاشة2', costC: 100000, priceC: 120000, stockQty: 0));
    final purId = await purchases.createPurchase(
      supplierId: supId,
      items: [PurchaseItem(productId: prodId, qty: 1, unitCostC: 100000, totalC: 100000)],
      discountC: 0,
      extraCostsC: 10000,
      paidC: 0,
      taxEnabled: true,
      taxRate: 19,
    );
    expect(purId, greaterThan(0));
    expect((await catalog.productById(prodId))!.stockQty, 1);
    expect((await people.supplierById(supId))!.balanceC, 107100);
  });

  test('returns: restock + refund + over-return rejected', () async {
    final db = EnvRepo<AppDatabase>(database);
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);
    final people = PeopleRepo(database, inventory);
    final sales = SalesRepo(database, inventory, SettingsRepo(database));
    final returns = ReturnsRepo(database, inventory, SettingsRepo(database));

    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Tapis', nameAr: 'سجادة', costC: 200000, priceC: 400000, stockQty: 6));
    final custId = await people.saveCustomer(
        Customer(nameFr: 'C3', nameAr: 'ع3', creditLimitC: 999999999));
    final saleId = await sales.createSale(
      customerId: custId,
      items: [SaleItem(
          productId: prodId, nameFr: 'Tapis', qty: 2,
          unitPriceC: 400000, unitCostC: 200000, totalC: 800000)],
      discountC: 0,
      paymentMethod: 'cash',
      paidC: 800000,
      taxEnabled: false,
      taxRate: 0,
    );
    final items = await sales.saleItems(saleId);

    final retId = await returns.createReturn(
        saleId: saleId, lines: [(items.first.id, 1)], reason: 'damaged');
    expect(retId, greaterThan(0));

    expect((await catalog.productById(prodId))!.stockQty, 5);

    final rets = await returns.returns(saleId: saleId);
    expect(rets.length, 1);
    expect(rets.first.totalC, 400000);
    expect(rets.first.reason, 'damaged');

    expect(await db.count('return_items'), 1);
    final refundPays = await db.rowsWhere('payments', "kind = 'refund'");
    expect(refundPays.length, 1);

    final items2 = await sales.saleItems(saleId);
    expect(items2.first.returnedQty, 1);
    await expectLater(
      returns.createReturn(saleId: saleId, lines: [(items2.first.id, 2)], reason: 'again'),
      throwsA(isA<AppException>()),
    );
  });

  test('sale cancellation restocks and never loses history', () async {
    final db = EnvRepo<AppDatabase>(database);
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);
    final sales = SalesRepo(database, inventory, SettingsRepo(database));

    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Clavier', nameAr: 'لوحة', costC: 150000, priceC: 250000, stockQty: 8));
    final saleId = await sales.createSale(
      items: [SaleItem(
          productId: prodId, nameFr: 'Clavier', qty: 2,
          unitPriceC: 250000, unitCostC: 150000, totalC: 500000)],
      discountC: 0,
      paymentMethod: 'cash',
      paidC: 500000,
      taxEnabled: false,
      taxRate: 0,
    );
    await sales.cancelSale(saleId);

    expect((await catalog.productById(prodId))!.stockQty, 8);
    final sale = (await sales.sales()).firstWhere((s) => s.id == saleId);
    expect(sale.status, 'cancelled');
    expect(await db.count('sales'), 1);
    expect((await inventory.movements()).where((m) => m.refType == 'cancel').length, 1);
  });

  test('profit calculations from real records', () async {
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);
    final people = PeopleRepo(database, inventory);
    final sales = SalesRepo(database, inventory, SettingsRepo(database));
    final expenses = ExpensesRepo(database);
    final analytics = AnalyticsRepo(database);

    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Eau', nameAr: 'ماء', costC: 10000, priceC: 15000, stockQty: 100));
    final custId = await people.saveCustomer(Customer(nameFr: 'C4', nameAr: 'ع4'));
    await sales.createSale(
      customerId: custId,
      items: [SaleItem(
          productId: prodId, nameFr: 'Eau', qty: 10,
          unitPriceC: 15000, unitCostC: 10000, totalC: 150000)],
      discountC: 0,
      paymentMethod: 'cash',
      paidC: 150000,
      taxEnabled: false,
      taxRate: 0,
    );

    final cats = await expenses.categories();
    expect(cats.length, 7);
    await expenses.add(
        categoryKey: cats.first.$1, description: 'Loyer', amountC: 20000,
        paidAt: DateTime.now().toUtc().toIso8601String().split('.').first,
        method: 'cash');

    const from = '2000-01-01T00:00:00';
    const to = '2999-12-31T23:59:59';
    expect(await analytics.salesSum(from, to), 150000);
    expect(await analytics.grossProfitC(from, to), 50000);
    expect(await analytics.expensesC(from, to), 20000);
    expect(await analytics.netProfitC(from, to), 30000);
  });

  test('cash register: open, expected cash, manual moves, close diff', () async {
    final db = EnvRepo<AppDatabase>(database);
    final cash = CashRepo(database);
    final inventory = InventoryRepo(database);
    final catalog = CatalogRepo(database);
    final sales = SalesRepo(database, inventory, SettingsRepo(database));
    final people = PeopleRepo(database, inventory);

    final regId = await cash.open(1000000);
    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Pain', nameAr: 'خبز', costC: 5000, priceC: 10000, stockQty: 50));
    final custId = await people.saveCustomer(Customer(nameFr: 'C5', nameAr: 'ع5'));
    await sales.createSale(
      customerId: custId,
      items: [SaleItem(
          productId: prodId, nameFr: 'Pain', qty: 2,
          unitPriceC: 10000, unitCostC: 5000, totalC: 20000)],
      discountC: 0,
      paymentMethod: 'cash',
      paidC: 20000,
      taxEnabled: false,
      taxRate: 0,
    );

    expect(await cash.expectedCash(regId), 1020000);

    await cash.manualMove(cashIn: true, amountC: 50000, reason: 'deposit');
    await cash.manualMove(cashIn: false, amountC: 20000, reason: 'withdrawal');
    expect(await cash.expectedCash(regId), 1050000);

    await cash.closeRegister(regId, 1040000);
    final closed = await cash.registers();
    expect(closed.first.status, 'closed');
    expect(closed.first.countedC, 1040000);
    expect(closed.first.closingC, 1050000);
    expect(closed.first.diffC, -10000);

    final reg2 = await cash.open(0);
    expect(reg2, greaterThan(0));
    await expectLater(cash.open(5000), throwsA(isA<AppException>()));
    expect(await db.count('cash_registers'), 2);
  });

  test('backup: VACUUM INTO snapshot contains the data', () async {
    final catalog = CatalogRepo(database);
    await catalog.saveProduct(
        Product(nameFr: 'Bic', nameAr: 'بنك', costC: 100, priceC: 200, stockQty: 3));
    final target = '${tmp.path}/backup.db';
    await AppDatabase.backupFile(database.db, target);

    await AppDatabase.instance.close();
    final restored = AppDatabase.instance;
    await restored.open(target);
    final tables = await restored.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
    expect(tables.length, greaterThanOrEqualTo(22));
    expect(await EnvRepo<AppDatabase>(restored).count('products'), 1);
    expect(await restored.integrityCheck(), true);
    await restored.close();
    expect(File(target).existsSync(), true);
  });
}

/// Tiny query helper so tests can assert on raw table state without
/// depending on repository read APIs.
class EnvRepo<T> {
  EnvRepo(this.d);
  final T d;

  Future<int> count(String table) async {
    final rows = await (d as AppDatabase).db.rawQuery('SELECT COUNT(*) c FROM $table');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<Map<String, Object?>>> rowsWhere(String table, String where) =>
      (d as AppDatabase).db.query(table, where: where);
}
