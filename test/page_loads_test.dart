import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dz_business_pro/core/money.dart';
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

  /// Replicates the Future.wait + cast pattern used by every page's
  /// _load/_reload. A wrong repo return type throws here just like in the UI,
  /// instead of leaving a page stuck on a spinner.
  Future<void> pageWaits(AppDatabase db, {required bool seeded}) async {
    final settings = SettingsRepo(db);
    final catalog = CatalogRepo(db);
    final inventory = InventoryRepo(db);
    final people = PeopleRepo(db, inventory);
    final sales = SalesRepo(db, inventory, settings);
    final purchases = PurchasesRepo(db, inventory, settings);
    final expenses = ExpensesRepo(db);
    final cash = CashRepo(db);
    final analytics = AnalyticsRepo(db);

    final now = DateTime.now();
    final from = Dates.iso(DateTime(now.year, now.month, 1));
    final to = Dates.dayEnd(now);
    final today = Dates.dayEnd(now);

    // dashboard
    final r = await Future.wait([
      analytics.dailySeries(14, today),
      analytics.monthlySeries(12),
      analytics.topProducts(limitN: 6),
      analytics.salesByMethod(from, to),
      analytics.recentSales(limit: 6),
      analytics.recentPayments(limit: 6),
      analytics.recentMovements(limit: 6),
    ]);
    final daily = r[0] as List<MapEntry<String, int>>;
    final monthly = r[1] as List<(String, int, int, int)>;
    final topProducts = r[2] as List<(String, int)>;
    final byMethod = r[3] as List<(String, int)>;
    final recentSales = r[4] as List<Sale>;
    final recentPayments = r[5] as List<Payment>;
    final recentMovements = r[6] as List<StockMovement>;
    expect(daily.length <= 14, true);
    expect(monthly.length <= 12, true);
    if (!seeded) {
      expect(topProducts, isEmpty);
      expect(byMethod, isEmpty);
      expect(recentSales, isEmpty);
      expect(recentPayments, isEmpty);
      expect(recentMovements, isEmpty);
    } else {
      expect(monthly.single.$1, '${now.year}-${now.month.toString().padLeft(2, '0')}');
      expect(monthly.single.$2, 240000, reason: 'monthly sales total');
      expect(monthly.single.$3, 50000, reason: 'monthly purchases total');
      expect(monthly.single.$4, 20000, reason: 'monthly expenses total');
      expect(topProducts.single.$1, 'Stylo');
      expect(byMethod.single.$1, 'partial');
    }

    // products / categories / brands
    final pr = await Future.wait([catalog.products(), catalog.categories(), catalog.brands(), people.suppliers()]);
    pr[0] as List<Product>;
    pr[1] as List<Category>;
    pr[2] as List<Brand>;
    pr[3] as List<Supplier>;

    // inventory
    final ir = await Future.wait([
      inventory.stockValueC(),
      inventory.stockUnits(),
      inventory.lowStockCount(),
      inventory.productCount(),
      catalog.products(onlyLowStock: true, includeArchived: true),
      inventory.movements(limit: 150),
      inventory.outCount(),
    ]);
    ir[0] as int;
    ir[1] as int;
    ir[2] as int;
    ir[3] as int;
    ir[4] as List<Product>;
    ir[5] as List<StockMovement>;
    ir[6] as int;

    // expenses
    final er = await Future.wait([
      expenses.list(from: from, to: to),
      expenses.categories(),
      expenses.monthly(12),
      expenses.totalC(from, to),
    ]);
    er[0] as List<Expense>;
    er[1] as List<(String, String, String)>;
    er[2] as List<MapEntry<String, int>>;
    er[3] as int;

    // purchases
    final pur = await Future.wait([purchases.purchases(), people.suppliers()]);
    pur[0] as List<Purchase>;
    pur[1] as List<Supplier>;

    // settings
    final sr = await Future.wait([
      settings.allowNegativeStock(),
      settings.backupOnClose(),
      settings.auditLog(limit: 60),
    ]);
    sr[0] as bool;
    sr[1] as bool;
    sr[2] as List<AuditEntry>;

    // customers / suppliers / invoices / pos
    Object? v6 = await people.customers(query: '');
    v6 as List<Customer>;
    Object? v7 = await people.suppliers(query: '');
    v7 as List<Supplier>;
    Object? v8 = await sales.sales();
    v8 as List<Sale>;
    Object? v9 = await catalog.products();
    v9 as List<Product>;

    // finance (raw scalar queries + cash history)
    final fr = await Future.wait([
      db.db.rawQuery('SELECT COALESCE(SUM(MAX(balance_c - credit_limit_c, 0)),0) AS v FROM customers'),
      db.db.rawQuery("SELECT COALESCE(SUM(amount_c),0) AS v FROM payments WHERE kind='payment' AND direction='sale' AND paid_at >= ? AND paid_at <= ?", [from, to]),
      cash.registers(),
      cash.movements(),
    ]);
    ((fr[0] as List<Map<String, Object?>>).first['v'] as int?) ?? 0;
    ((fr[1] as List<Map<String, Object?>>).first['v'] as int?) ?? 0;
    fr[2] as List<CashRegister>;
    fr[3] as List<CashMovement>;

    expect(await db.integrityCheck(), true);
  }

  Future<int> count(String table) async {
    final rows = await database.db.rawQuery('SELECT COUNT(*) c FROM $table');
    return (rows.first['c'] as int?) ?? 0;
  }

  test('empty database: every page load pattern completes with typed results', () async {
    await pageWaits(database, seeded: false);
  });

  test('seeded database: sales, purchases, expenses, cash and dashboard series', () async {
    final catalog = CatalogRepo(database);
    final inventory = InventoryRepo(database);
    final people = PeopleRepo(database, inventory);
    final settings = SettingsRepo(database);
    final sales = SalesRepo(database, inventory, settings);
    final purchasesRepo = PurchasesRepo(database, inventory, settings);
    final expenses = ExpensesRepo(database);
    final cash = CashRepo(database);

    await catalog.addCategory('فئة', 'Categorie');
    final prodId = await catalog.saveProduct(
        Product(nameFr: 'Stylo', nameAr: 'قلم', costC: 50000, priceC: 80000, stockQty: 10));
    final custId = await people.saveCustomer(Customer(nameFr: 'Client', nameAr: 'عميل', creditLimitC: 500000));

    final saleId = await sales.createSale(
      customerId: custId,
      items: [SaleItem(productId: prodId, nameFr: 'Stylo', qty: 3, unitPriceC: 80000, unitCostC: 50000, totalC: 240000)],
      discountC: 0,
      paymentMethod: 'partial',
      paidC: 100000,
      taxEnabled: false,
      taxRate: 0,
    );
    expect(saleId > 0, true);

    final supId = await people.saveSupplier(Supplier(nameFr: 'Fournisseur', nameAr: 'مورد'));
    await purchasesRepo.createPurchase(
      supplierId: supId,
      items: [PurchaseItem(productId: prodId, qty: 1, unitCostC: 50000, totalC: 50000)],
      discountC: 0,
      extraCostsC: 0,
      paidC: 50000,
      taxEnabled: false,
      taxRate: 0,
    );

    final cats = await expenses.categories();
    await expenses.add(categoryKey: cats.first.$1, description: 'Loyer', amountC: 20000, paidAt: Dates.iso(DateTime.now()), method: 'cash');
    expect(await count('expenses'), 1);

    final regId = await cash.open(10000);
    expect(regId > 0, true);
    expect(await cash.expectedCash(regId), -10000, reason: 'opening 10000 minus the 20000 cash expense recorded as an out movement');

    await pageWaits(database, seeded: true);
  });
}
