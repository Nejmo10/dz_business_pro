import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/utils/utils.dart';
import '../models/models.dart';
import '../database/app_database.dart';
import '../../core/money.dart';

class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SalesTotals {
  SalesTotals({required this.subtotalC, required this.discountC, required this.taxC, required this.totalC});
  final int subtotalC, discountC, taxC, totalC;
}

SalesTotals computeTotals({
  required int subtotalC,
  required int discountC,
  required bool taxEnabled,
  required int taxRate,
}) {
  final taxable = (subtotalC - discountC).clamp(0, subtotalC);
  final tax = taxEnabled ? (taxable * taxRate / 100).round() : 0;
  return SalesTotals(
      subtotalC: subtotalC, discountC: discountC, taxC: tax, totalC: taxable + tax);
}

/// ---------------------------------------------------------------------------
/// Settings / profile / audit
/// ---------------------------------------------------------------------------
class SettingsRepo {
  SettingsRepo(this.db);
  final AppDatabase db;

  Future<String> get(String key, [String def = '']) async {
    final rows = await db.db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    return (rows.isEmpty ? null : rows.first['value'] as String?) ?? def;
  }

  Future<int> getInt(String key, [int def = 0]) async {
    final v = await get(key);
    return v.isEmpty ? def : int.tryParse(v) ?? def;
  }

  Future<void> set(String key, String value) =>
      db.db.insert('app_settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> setInt(String key, int value) => set(key, '$value');

  Future<bool> allowNegativeStock() async => await getInt('allow_negative_stock') == 1;
  Future<void> setAllowNegativeStock(bool v) => setInt('allow_negative_stock', v ? 1 : 0);

  Future<bool> backupOnClose() async => await getInt('backup_on_close') == 1;
  Future<void> setBackupOnClose(bool v) => setInt('backup_on_close', v ? 1 : 0);

  Future<bool> hasBusinessProfile() async {
    final rows = await db.db.query('business_profile', limit: 1);
    return rows.isNotEmpty;
  }

  Future<BusinessProfile> loadProfile() async {
    final rows = await db.db.query('business_profile', limit: 1);
    if (rows.isEmpty) return BusinessProfile();
    return BusinessProfile.fromRow(rows.first);
  }

  Future<void> saveProfile(BusinessProfile p) async {
    final now = Dates.iso(DateTime.now());
    await db.db.insert('business_profile', {
      'id': 1, 'name': p.name, 'activity': p.activity, 'logo_path': p.logoPath,
      'address': p.address, 'phone': p.phone, 'email': p.email,
      'language': p.language, 'currency': p.currency,
      'tax_enabled': p.taxEnabled ? 1 : 0, 'tax_rate': p.taxRate,
      'receipt_format': p.receiptFormat, 'invoice_prefix': p.invoicePrefix,
      'created_at': p.createdAt.isEmpty ? now : p.createdAt, 'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await set('app_language', p.language);
  }

  Future<void> audit(String action, String entity, int? entityId, String details) async {
    await db.db.insert('audit_logs', {
      'action': action, 'entity': entity, 'entity_id': entityId,
      'details': details, 'actor': 'local', 'logged_at': Dates.iso(DateTime.now()),
    });
  }

  Future<List<AuditEntry>> auditLog({int limit = 300}) async {
    final rows = await db.db.query('audit_logs',
        orderBy: 'id DESC', limit: limit);
    return rows.map(AuditEntry.fromRow).toList();
  }
}

/// ---------------------------------------------------------------------------
/// Catalog: categories, brands, products
/// ---------------------------------------------------------------------------
class CatalogRepo {
  CatalogRepo(this.db);
  final AppDatabase db;

  Future<List<Category>> categories() async {
    final rows = await db.db.rawQuery('''
      SELECT c.*, (SELECT COUNT(*) FROM products p WHERE p.category_id = c.id) AS cnt
      FROM categories c ORDER BY c.name_fr''');
    return rows.map(Category.fromRow).toList();
  }

  Future<int> addCategory(String nameAr, String nameFr) async {
    final now = Dates.iso(DateTime.now());
    return db.db.insert('categories', {'name_ar': nameAr, 'name_fr': nameFr, 'created_at': now});
  }

  Future<void> updateCategory(int id, String nameAr, String nameFr) =>
      db.db.update('categories', {'name_ar': nameAr, 'name_fr': nameFr}, where: 'id = ?', whereArgs: [id]);

  Future<void> deleteCategory(int id) =>
      db.db.delete('categories', where: 'id = ?', whereArgs: [id]);

  Future<List<Brand>> brands() async {
    final rows = await db.db.rawQuery('''
      SELECT b.*, (SELECT COUNT(*) FROM products p WHERE p.brand_id = b.id) AS cnt
      FROM brands b ORDER BY b.name_fr''');
    return rows.map(Brand.fromRow).toList();
  }

  Future<int> addBrand(String nameAr, String nameFr) async {
    final now = Dates.iso(DateTime.now());
    return db.db.insert('brands', {'name_ar': nameAr, 'name_fr': nameFr, 'created_at': now});
  }

  Future<void> deleteBrand(int id) => db.db.delete('brands', where: 'id = ?', whereArgs: [id]);

  Future<void> updateBrand(int id, String nameAr, String nameFr) =>
      db.db.update('brands', {'name_ar': nameAr, 'name_fr': nameFr}, where: 'id = ?', whereArgs: [id]);

  Future<List<Product>> products({
    String query = '',
    int? categoryId,
    bool includeArchived = false,
    bool onlyLowStock = false,
    int limit = 2000,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeArchived) where.add('p.archived = 0');
    if (categoryId != null) { where.add('p.category_id = ?'); args.add(categoryId); }
    if (query.isNotEmpty) {
      where.add('(p.name_ar LIKE ? OR p.name_fr LIKE ? OR p.sku LIKE ? OR p.barcode LIKE ?)');
      args.addAll(['%$query%', '%$query%', '%$query%', '%$query%']);
    }
    final rows = await db.db.rawQuery('''
      SELECT p.*, c.name_fr AS cat_name_fr FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY p.updated_at DESC ${onlyLowStock ? '' : 'LIMIT $limit'}
    ''', args);
    var list = rows.map(Product.fromRow).toList();
    if (onlyLowStock) {
      list = list.where((p) => p.stockQty <= p.minStock).toList();
    }
    return list;
  }

  Future<Product?> productById(int id) async {
    final rows = await db.db.query('products', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Product.fromRow(rows.first);
  }

  Future<Product?> productByBarcode(String barcode) async {
    final rows = await db.db.query('products',
        where: 'barcode = ? AND archived = 0', whereArgs: [barcode], limit: 1);
    return rows.isEmpty ? null : Product.fromRow(rows.first);
  }

  /// Creates or updates [p]. Caller must notify listeners.
  Future<int> saveProduct(Product p) async {
    final now = Dates.iso(DateTime.now());
    final row = {
      'name_ar': p.nameAr, 'name_fr': p.nameFr, 'sku': p.sku.isEmpty ? null : p.sku,
      'barcode': p.barcode.isEmpty ? null : p.barcode, 'category_id': p.categoryId,
      'brand_id': p.brandId, 'supplier_id': p.supplierId, 'cost_c': p.costC,
      'price_c': p.priceC, 'wholesale_c': p.wholesaleC, 'stock_qty': p.stockQty,
      'min_stock': p.minStock, 'max_stock': p.maxStock, 'image_path': p.imagePath,
      'description': p.description, 'archived': p.archived ? 1 : 0, 'updated_at': now,
    };
    return db.db.transaction<int>((tx) async {
      int? oldStock;
      if (p.id != 0) {
        final rows = await tx.query('products', where: 'id = ?', whereArgs: [p.id], limit: 1);
        if (rows.isNotEmpty) oldStock = Product.fromRow(rows.first).stockQty;
      }
      int id;
      if (p.id == 0) {
        row['created_at'] = now;
        id = await tx.insert('products', row);
      } else {
        await tx.update('products', row, where: 'id = ?', whereArgs: [p.id]);
        id = p.id;
      }
      final old = oldStock ?? 0;
      if (old != p.stockQty) {
        final diff = p.stockQty - old;
        await tx.insert('stock_movements', {
          'product_id': id, 'type': diff > 0 ? 'in' : 'out', 'qty': diff.abs(),
          'balance_after': p.stockQty, 'ref_type': 'manual',
          'unit_cost_c': p.costC, 'note': p.id == 0 ? 'initial stock' : 'adjustment',
          'moved_at': now,
        });
        await tx.insert('audit_logs', {
          'action': p.id == 0 ? 'product_create' : 'product_update', 'entity': 'products',
          'entity_id': id, 'details': p.nameFr, 'actor': 'local', 'logged_at': now,
        });
      }
      return id;
    });
  }

  Future<void> archiveProduct(int id, bool archived) => db.db
      .update('products', {'archived': archived ? 1 : 0, 'updated_at': Dates.iso(DateTime.now())}, where: 'id = ?', whereArgs: [id]);

  Future<int> deleteProduct(int id) async {
    final sold = firstIntValue(await db.db.rawQuery(
        'SELECT COUNT(*) FROM sale_items WHERE product_id = ?', [id])) ?? 0;
    if (sold > 0) {
      await archiveProduct(id, true);
      return 0;
    }
    return db.db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> soldQuantity(int productId) async =>
      firstIntValue(await db.db.rawQuery(
        'SELECT COALESCE(SUM(qty - returned_qty),0) FROM sale_items WHERE product_id = ?',
        [productId])) ?? 0;
}

/// ---------------------------------------------------------------------------
/// Inventory: movements with full audit (every change leaves a trace)
/// ---------------------------------------------------------------------------
class InventoryRepo {
  InventoryRepo(this.db);
  final AppDatabase db;

  Future<void> moveStock(Transaction tx, {
    required int productId,
    required String type,
    required int qty,
    required int balanceAfter,
    String? refType,
    int? refId,
    int? unitCostC,
    String note = '',
  }) async {
    await tx.insert('stock_movements', {
      'product_id': productId, 'type': type, 'qty': qty,
      'balance_after': balanceAfter, 'ref_type': refType, 'ref_id': refId,
      'unit_cost_c': unitCostC, 'note': note, 'moved_at': Dates.iso(DateTime.now()),
    });
  }

  Future<List<StockMovement>> movements({int? productId, int limit = 500}) async {
    final rows = await db.db.rawQuery('''
      SELECT m.*, p.name_fr AS p_fr, p.name_ar AS p_ar
      FROM stock_movements m JOIN products p ON p.id = m.product_id
      ${productId != null ? 'WHERE m.product_id = ?' : ''}
      ORDER BY m.id DESC LIMIT $limit''', productId != null ? [productId] : null);
    return rows.map(StockMovement.fromRow).toList();
  }

  Future<int> stockValueC() async =>
      firstIntValue(await db.db.rawQuery(
          'SELECT COALESCE(SUM(stock_qty * cost_c),0) FROM products WHERE archived = 0')) ?? 0;

  Future<int> stockUnits() async =>
      firstIntValue(await db.db.rawQuery(
          'SELECT COALESCE(SUM(stock_qty),0) FROM products WHERE archived = 0')) ?? 0;

  Future<int> lowStockCount() async =>
      firstIntValue(await db.db.rawQuery(
          'SELECT COUNT(*) FROM products WHERE archived = 0 AND stock_qty <= min_stock')) ?? 0;

  Future<int> outCount() async =>
      firstIntValue(await db.db.rawQuery(
          'SELECT COUNT(*) FROM products WHERE stock_qty <= 0')) ?? 0;

  Future<int> productCount() async =>
      firstIntValue(await db.db.rawQuery(
          'SELECT COUNT(*) FROM products WHERE archived = 0')) ?? 0;

  Future<void> applyManualMove({
    required int productId,
    required String type,
    required int qty,
    required String note,
  }) async {
    final product = await db.db.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
    if (product.isEmpty) throw AppException('product: $productId not found');
    final p = Product.fromRow(product.first);
    final delta = type == 'out' ? -qty.abs() : qty.abs();
    final newBalance = p.stockQty + delta;
    if (newBalance < 0 && !await dbNegativeAllowed()) {
      throw AppException('Stock cannot go negative');
    }
    await db.db.transaction((tx) async {
      await tx.update('products', {'stock_qty': newBalance, 'updated_at': Dates.iso(DateTime.now())},
          where: 'id = ?', whereArgs: [productId]);
      await moveStock(tx,
          productId: productId,
          type: delta >= 0 ? 'in' : 'out',
          qty: delta.abs(),
          balanceAfter: newBalance,
          refType: 'manual',
          note: note);
      await _audit(tx, 'stock_$type', 'product', productId, '$qty @ $note');
    });
  }

  Future<bool> dbNegativeAllowed() async =>
      firstIntValue(await db.db.rawQuery(
          "SELECT COUNT(*) FROM app_settings WHERE key='allow_negative_stock' AND value='1'")) == 1;

  Future<void> _audit(Transaction tx, String action, String entity, int? id, String details) async {
    await tx.insert('audit_logs', {
      'action': action, 'entity': entity, 'entity_id': id, 'details': details,
      'actor': 'local', 'logged_at': Dates.iso(DateTime.now()),
    });
  }
}

/// ---------------------------------------------------------------------------
/// People: customers, suppliers, their payments & balances
/// ---------------------------------------------------------------------------
class PeopleRepo {
  PeopleRepo(this.db, this.inventory);
  final AppDatabase db;
  final InventoryRepo inventory;

  Future<List<Customer>> customers({String query = ''}) async {
    final rows = await db.db.query('customers',
        where: query.isEmpty
            ? 'active = 1'
            : '(active = 1 AND (name_ar LIKE ? OR name_fr LIKE ? OR phone LIKE ?))',
        whereArgs: query.isEmpty ? null : ['%$query%', '%$query%', '%$query%'],
        orderBy: 'name_fr');
    return rows.map(Customer.fromRow).toList();
  }

  Future<Customer?> customerById(int id) async {
    final rows = await db.db.query('customers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Customer.fromRow(rows.first);
  }

  Future<int> saveCustomer(Customer c) async {
    final now = Dates.iso(DateTime.now());
    final row = <String, Object?>{
      'name_ar': c.nameAr, 'name_fr': c.nameFr, 'phone': c.phone, 'email': c.email,
      'address': c.address, 'notes': c.notes, 'type': c.type,
      'credit_limit_c': c.creditLimitC, 'balance_c': c.balanceC, 'active': c.active ? 1 : 0,
    };
    if (c.id == 0) { row['created_at'] = now; return db.db.insert('customers', row); }
    await db.db.update('customers', row, where: 'id = ?', whereArgs: [c.id]);
    return c.id;
  }

  Future<int> deleteCustomer(int id) =>
      db.db.rawDelete('DELETE FROM customers WHERE id = ?', [id]);

  Future<List<Supplier>> suppliers({String query = ''}) async {
    final rows = await db.db.query('suppliers',
        where: query.isEmpty ? 'active = 1' : '(active = 1 AND (name_ar LIKE ? OR name_fr LIKE ? OR company LIKE ?))',
        whereArgs: query.isEmpty ? null : ['%$query%', '%$query%', '%$query%'],
        orderBy: 'name_fr');
    return rows.map(Supplier.fromRow).toList();
  }

  Future<Supplier?> supplierById(int id) async {
    final rows = await db.db.query('suppliers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Supplier.fromRow(rows.first);
  }

  Future<int> saveSupplier(Supplier s) async {
    final now = Dates.iso(DateTime.now());
    final row = <String, Object?>{
      'name_ar': s.nameAr, 'name_fr': s.nameFr, 'company': s.company, 'contact': s.contact,
      'phone': s.phone, 'email': s.email, 'address': s.address, 'notes': s.notes,
      'balance_c': s.balanceC, 'active': s.active ? 1 : 0,
    };
    if (s.id == 0) { row['created_at'] = now; return db.db.insert('suppliers', row); }
    await db.db.update('suppliers', row, where: 'id = ?', whereArgs: [s.id]);
    return s.id;
  }

  Future<int> deleteSupplier(int id) =>
      db.db.rawDelete('DELETE FROM suppliers WHERE id = ?', [id]);

  Future<List<Payment>> payments({required String direction, int? partyId, int limit = 200}) async {
    final rows = await db.db.query('payments',
        where: 'direction = ?${partyId != null ? ' AND party_id = ?' : ''}',
        whereArgs: partyId != null ? [direction, partyId] : [direction],
        orderBy: 'id DESC', limit: limit);
    return rows.map(Payment.fromRow).toList();
  }

  /// Records a payment against a customer [direction='sale'] or supplier
  /// [direction='purchase'], adjusting the running balance. One transaction.
  Future<void> recordPayment({
    required String direction,
    required int refId,
    int? partyId,
    required int amountC,
    required String method,
    String notes = '',
  }) async {
    final now = Dates.iso(DateTime.now());
    final table = direction == 'sale' ? 'customers' : 'suppliers';
    final paidField = direction == 'sale' ? 'sales' : 'purchases';
    final paidCol = direction == 'sale' ? 'paid_c' : 'paid_c';

    await db.db.transaction((tx) async {
      // Enforce party exists & compute new balance.
      final rows = await tx.query(table, where: 'id = ?', whereArgs: [partyId], limit: 1);
      if (rows.isEmpty) throw AppException('party not found');
      final balance = direction == 'sale'
          ? Customer.fromRow(rows.first).balanceC
          : Supplier.fromRow(rows.first).balanceC;
      final newBalance = direction == 'sale' ? balance - amountC : balance - amountC;
      await tx.update(table, {'balance_c': newBalance}, where: 'id = ?', whereArgs: [partyId]);

      await tx.insert('payments', {
        'direction': direction, 'ref_id': refId, 'party_id': partyId,
        'amount_c': amountC, 'method': method, 'kind': 'payment',
        'paid_at': now, 'notes': notes,
      });

      // Update the related sale/purchase paid totals.
      await tx.rawUpdate(
          'UPDATE $paidField SET paid_c = paid_c + ? WHERE id = ?', [amountC, refId]);

      await tx.insert('audit_logs', {
        'action': 'payment', 'entity': table, 'entity_id': partyId,
        'details': '${direction == 'sale' ? 'customer' : 'supplier'} payment $amountC on $paidCol ref=$refId',
        'actor': 'local', 'logged_at': now,
      });
    });
  }

  Future<List<Map<String, Object?>>> customerSales(int customerId) async =>
      db.db.query('sales',
          where: 'customer_id = ?',
          orderBy: 'id DESC', limit: 200, whereArgs: [customerId]);

  Future<List<Map<String, Object?>>> supplierPurchases(int supplierId) async =>
      db.db.query('purchases',
          where: 'supplier_id = ?',
          orderBy: 'id DESC', limit: 200, whereArgs: [supplierId]);

  Future<int> totalCustomerDebt() async =>
      firstIntValue(await db.db.rawQuery(
          'SELECT COALESCE(SUM(balance_c),0) FROM customers WHERE balance_c > 0')) ?? 0;

  Future<int> totalSupplierDebt() async =>
      firstIntValue(await db.db.rawQuery(
          'SELECT COALESCE(SUM(balance_c),0) FROM suppliers WHERE balance_c > 0')) ?? 0;
}

/// ---------------------------------------------------------------------------
/// Sales: the full POS checkout as one atomic transaction
/// ---------------------------------------------------------------------------
class SalesRepo {
  SalesRepo(this.db, this.inventory, this.settings);
  final AppDatabase db;
  final InventoryRepo inventory;
  final SettingsRepo settings;

  Future<List<Sale>> sales({int? customerId, String from = '', String to = '', int limit = 500}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (customerId != null) { where.add('customer_id = ?'); args.add(customerId); }
    if (from.isNotEmpty) { where.add('sale_at >= ?'); args.add(from); }
    if (to.isNotEmpty) { where.add('sale_at <= ?'); args.add(to); }
    if (where.isEmpty) where.add("status != ''");
    final rows = await db.db.query('sales',
        where: where.join(' AND '), whereArgs: args,
        orderBy: 'id DESC', limit: limit);
    return rows.map(Sale.fromRow).toList();
  }

  Future<Sale?> saleById(int id) async {
    final rows = await db.db.query('sales', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Sale.fromRow(rows.first);
  }

  Future<List<SaleItem>> saleItems(int saleId) async =>
      (await db.db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]))
          .map(SaleItem.fromRow).toList();

  /// Full POS checkout. Everything succeeds or nothing is persisted.
  Future<int> createSale({
    int? customerId,
    required List<SaleItem> items,
    required int discountC,
    required String paymentMethod,
    required int paidC,
    required bool taxEnabled,
    required int taxRate,
    int? userId,
    String notes = '',
  }) async {
    if (items.isEmpty) throw AppException('empty cart');
    final negativeOk = await settings.allowNegativeStock();
    final now = Dates.iso(DateTime.now());

    return db.db.transaction<int>((tx) async {
      for (final it in items) {
        final rows = await tx.query('products', where: 'id = ?', whereArgs: [it.productId], limit: 1);
        if (rows.isEmpty) throw AppException('product ${it.productId} not found');
        final p = Product.fromRow(rows.first);
        if (!negativeOk && p.archived) throw AppException('product archived: ${p.nameFr}');
        if (!negativeOk && p.stockQty < it.qty) {
          throw AppException('insufficient stock for ${p.nameFr}');
        }
      }

      final subtotal = items.fold<int>(0, (s, i) => s + i.qty * i.unitPriceC - i.discountC);
      final totals = computeTotals(
          subtotalC: subtotal, discountC: discountC, taxEnabled: taxEnabled, taxRate: taxRate);

      final rows = await tx.query('app_settings', where: 'key = ?', whereArgs: ['sale_counter'], limit: 1);
      final n = ((rows.isEmpty ? 0 : int.parse(rows.first['value'] as String))) + 1;
      await tx.update('app_settings', {'value': '$n'}, where: 'key = ?', whereArgs: ['sale_counter']);
      final prefixRows = await tx.query('business_profile', limit: 1);
      final prefix = prefixRows.isEmpty ? 'F' : prefixRows.first['invoice_prefix'] as String? ?? 'F';
      final invoiceNo = '$prefix-${n.toString().padLeft(5, '0')}';

      final paidFinal = paymentMethod == 'credit' ? 0 : paidC.clamp(0, totals.totalC);
      final saleId = await tx.insert('sales', {
        'invoice_no': invoiceNo, 'customer_id': customerId, 'sale_at': now,
        'subtotal_c': totals.subtotalC, 'discount_c': discountC, 'tax_c': totals.taxC,
        'total_c': totals.totalC, 'paid_c': paidFinal,
        'status': 'completed', 'payment_method': paymentMethod, 'user_id': userId,
        'notes': notes,
      });

      for (final it in items) {
        final lines = await tx.query('products', where: 'id = ?', whereArgs: [it.productId], limit: 1);
        final p = Product.fromRow(lines.first);
        await tx.insert('sale_items', {
          'sale_id': saleId, 'product_id': it.productId,
          'name_ar': p.nameAr, 'name_fr': p.nameFr, 'qty': it.qty,
          'unit_price_c': it.unitPriceC, 'unit_cost_c': p.costC,
          'discount_c': it.discountC, 'total_c': it.qty * it.unitPriceC - it.discountC,
        });

        final newBalance = p.stockQty - it.qty;
        if (newBalance < 0 && !negativeOk) throw AppException('insufficient stock');
        await tx.update('products', {'stock_qty': newBalance, 'updated_at': now},
            where: 'id = ?', whereArgs: [it.productId]);
        await inventory.moveStock(tx,
            productId: it.productId, type: 'out', qty: it.qty,
            balanceAfter: newBalance, refType: 'sale', refId: saleId,
            unitCostC: p.costC, note: invoiceNo);
      }

      if (totals.totalC > 0 && paidFinal > 0) {
        await tx.insert('payments', {
          'direction': 'sale', 'ref_id': saleId, 'party_id': customerId,
          'amount_c': paidFinal, 'method': paymentMethod,
          'kind': 'payment', 'paid_at': now, 'notes': notes,
        });
      }

      if (customerId != null) {
        final due = totals.totalC - paidFinal;
        if (due > 0) {
          await tx.rawUpdate('UPDATE customers SET balance_c = balance_c + ? WHERE id = ?',
              [due, customerId]);
        }
      }

      await tx.insert('invoices', {
        'number': invoiceNo, 'type': 'sale', 'ref_id': saleId, 'issued_at': now,
        'total_c': totals.totalC, 'status': 'open',
      });
      await tx.insert('audit_logs', {
        'action': 'sale_create', 'entity': 'sales', 'entity_id': saleId,
        'details': invoiceNo, 'actor': 'local', 'logged_at': now,
      });
      return saleId;
    });
  }

  /// Cancels a sale: restocks everything, reverses customer balance and records
  /// a reversing refund payment. History is never deleted.
  Future<void> cancelSale(int saleId) async {
    await db.db.transaction((tx) async {
      final rows = await tx.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (rows.isEmpty) throw AppException('sale not found');
      final sale = Sale.fromRow(rows.first);
      if (sale.status == 'cancelled') throw AppException('already cancelled');
      final rets = await tx.query('returns', where: 'sale_id = ?', whereArgs: [saleId], limit: 1);
      if (rets.isNotEmpty) throw AppException('sale has returns');

      final now = Dates.iso(DateTime.now());
      final items = await tx.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      for (final row in items) {
        final it = SaleItem.fromRow(row);
        final prows = await tx.query('products', where: 'id = ?', whereArgs: [it.productId], limit: 1);
        final p = Product.fromRow(prows.first);
        final nb = p.stockQty + it.qty;
        await tx.update('products', {'stock_qty': nb, 'updated_at': now},
            where: 'id = ?', whereArgs: [it.productId]);
        await inventory.moveStock(tx,
            productId: it.productId, type: 'in', qty: it.qty,
            balanceAfter: nb, refType: 'cancel', refId: saleId,
            unitCostC: p.costC, note: 'cancel ${sale.invoiceNo}');
      }

      if (sale.customerId != null && sale.totalC > sale.paidC) {
        await tx.rawUpdate(
            'UPDATE customers SET balance_c = MAX(0, balance_c - ?) WHERE id = ?',
            [sale.totalC - sale.paidC, sale.customerId]);
      }
      if (sale.paidC > 0) {
        await tx.insert('payments', {
          'direction': 'sale', 'ref_id': saleId, 'party_id': sale.customerId,
          'amount_c': sale.paidC, 'method': sale.paymentMethod, 'kind': 'refund',
          'paid_at': now, 'notes': 'cancel ${sale.invoiceNo}',
        });
      }
      await tx.update('sales', {'status': 'cancelled'}, where: 'id = ?', whereArgs: [saleId]);
      await tx.update('invoices', {'status': 'cancelled'},
          where: "type='sale' AND ref_id = ?", whereArgs: [saleId]);
      await tx.insert('audit_logs', {
        'action': 'sale_cancel', 'entity': 'sales', 'entity_id': saleId,
        'details': sale.invoiceNo, 'actor': 'local', 'logged_at': now,
      });
    });
  }
}

/// ---------------------------------------------------------------------------
/// Returns (refunds) with stock and balance correction
/// ---------------------------------------------------------------------------
class ReturnsRepo {
  ReturnsRepo(this.db, this.inventory, this.settings);
  final AppDatabase db;
  final InventoryRepo inventory;
  final SettingsRepo settings;

  /// Creates a return for [lines] = (saleItemId, qty) of one sale.
  Future<int> createReturn({
    required int saleId,
    required List<(int, int)> lines,
    required String reason,
  }) async {
    if (lines.isEmpty) throw AppException('empty return');
    final now = Dates.iso(DateTime.now());
    return db.db.transaction<int>((tx) async {
      final srows = await tx.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
      if (srows.isEmpty) throw AppException('sale not found');
      final sale = Sale.fromRow(srows.first);

      final rows = await tx.query('app_settings', where: 'key = ?', whereArgs: ['return_counter'], limit: 1);
      final n = (rows.isEmpty ? 0 : int.parse(rows.first['value'] as String)) + 1;
      await tx.update('app_settings', {'value': '$n'}, where: 'key = ?', whereArgs: ['return_counter']);

      int total = 0;
      final returnId = await tx.insert('returns', {
        'return_no': 'R${n.toString().padLeft(5, '0')}', 'sale_id': saleId,
        'customer_id': sale.customerId, 'return_at': now, 'total_c': 0,
        'refunded_c': 0, 'reason': reason,
      });

      for (final (saleItemId, qty) in lines) {
        final irows = await tx.query('sale_items', where: 'id = ?', whereArgs: [saleItemId], limit: 1);
        if (irows.isEmpty) throw AppException('line not found');
        final it = SaleItem.fromRow(irows.first);
        final prior = it.returnedQty;
        if (qty <= 0 || prior + qty > it.qty) throw AppException('quantity');
        final lineRefund = (it.totalC / it.qty).round() * qty;
        total += lineRefund;
        await tx.insert('return_items', {
          'return_id': returnId, 'sale_item_id': saleItemId,
          'product_id': it.productId, 'qty': qty,
          'unit_price_c': it.unitPriceC, 'total_c': lineRefund,
        });
        await tx.update('sale_items', {'returned_qty': prior + qty}, where: 'id = ?', whereArgs: [saleItemId]);
        final prows = await tx.query('products', where: 'id = ?', whereArgs: [it.productId], limit: 1);
        final p = Product.fromRow(prows.first);
        final nb = p.stockQty + qty;
        await tx.update('products', {'stock_qty': nb, 'updated_at': now}, where: 'id = ?', whereArgs: [it.productId]);
        await inventory.moveStock(tx,
            productId: it.productId, type: 'in', qty: qty, balanceAfter: nb,
            refType: 'return', refId: saleId, unitCostC: p.costC, note: 'return $reason');
      }

      await tx.update('returns', {'total_c': total, 'refunded_c': total}, where: 'id = ?', whereArgs: [returnId]);

      if (sale.paymentMethod == 'credit' && sale.customerId != null) {
        await tx.rawUpdate('UPDATE customers SET balance_c = MAX(0, balance_c - ?) WHERE id = ?',
            [total, sale.customerId]);
        await tx.insert('payments', {
          'direction': 'sale', 'ref_id': saleId, 'party_id': sale.customerId,
          'amount_c': total, 'method': 'credit', 'kind': 'refund', 'paid_at': now,
          'notes': 'return $reason',
        });
      } else if (total > 0) {
        await tx.insert('payments', {
          'direction': 'sale', 'ref_id': saleId, 'party_id': sale.customerId,
          'amount_c': total, 'method': 'cash', 'kind': 'refund', 'paid_at': now,
          'notes': 'return $reason',
        });
      }

      await tx.insert('audit_logs', {
        'action': 'return_create', 'entity': 'returns', 'entity_id': returnId,
        'details': '${sale.invoiceNo} $reason', 'actor': 'local', 'logged_at': now,
      });
      return returnId;
    });
  }

  Future<List<ReturnRec>> returns({required int saleId}) async {
    final rows = await db.db.query('returns', where: 'sale_id = ?', whereArgs: [saleId], orderBy: 'id DESC');
    return rows.map((r) => ReturnRec(
          id: r['id'] as int,
          returnNo: r['return_no'] as String,
          saleId: saleId,
          returnAt: r['return_at'] as String,
          totalC: r['total_c'] as int,
          refundedC: r['refunded_c'] as int,
          reason: r['reason'] as String? ?? '',
        )).toList();
  }
}

/// ---------------------------------------------------------------------------
/// Purchases: supplier orders, stock input, payables
/// ---------------------------------------------------------------------------
class PurchasesRepo {
  PurchasesRepo(this.db, this.inventory, this.settings);
  final AppDatabase db;
  final InventoryRepo inventory;
  final SettingsRepo settings;

  Future<List<Purchase>> purchases({int? supplierId, int limit = 300}) async {
    final rows = await db.db.query('purchases',
        where: supplierId != null ? 'supplier_id = ?' : null,
        whereArgs: supplierId != null ? [supplierId] : null,
        orderBy: 'id DESC', limit: limit);
    return rows.map(Purchase.fromRow).toList();
  }

  Future<List<PurchaseItem>> purchaseItems(int purchaseId) async {
    final rows = await db.db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [purchaseId]);
    return rows.map((r) => PurchaseItem(
          productId: r['product_id'] as int,
          qty: r['qty'] as int,
          unitCostC: r['unit_cost_c'] as int,
          totalC: r['total_c'] as int,
          nameAr: r['name_ar'] as String? ?? '',
          nameFr: r['name_fr'] as String? ?? '',
        )).toList();
  }

  /// Confirms a purchase in one transaction; stock increases and the supplier
  /// payable (or payment) is recorded.
  Future<int> createPurchase({
    int? supplierId,
    required List<PurchaseItem> items,
    required int discountC,
    required int extraCostsC,
    required int paidC,
    required bool taxEnabled,
    required int taxRate,
    bool updateCostPrices = true,
    String notes = '',
  }) async {
    if (items.isEmpty) throw AppException('no items');
    if (supplierId == null) throw AppException('no supplier');
    final now = Dates.iso(DateTime.now());
    return db.db.transaction<int>((tx) async {
      final subtotal = items.fold<int>(0, (s, i) => s + i.qty * i.unitCostC);
      final net = subtotal - discountC - extraCostsC;
      final total = taxEnabled ? net + (net * taxRate / 100).round() : net;

      final rows = await tx.query('app_settings', where: 'key = ?', whereArgs: ['purchase_counter'], limit: 1);
      final n = (rows.isEmpty ? 0 : int.parse(rows.first['value'] as String)) + 1;
      await tx.update('app_settings', {'value': '$n'}, where: 'key = ?', whereArgs: ['purchase_counter']);
      final invoiceNo = 'B-${n.toString().padLeft(5, '0')}';

      final paid = paidC.clamp(0, total);
      final purchaseId = await tx.insert('purchases', {
        'invoice_no': invoiceNo, 'supplier_id': supplierId, 'purchase_at': now,
        'subtotal_c': subtotal, 'discount_c': discountC, 'tax_c': total - net,
        'extra_costs_c': extraCostsC, 'total_c': total, 'paid_c': paid,
        'status': 'confirmed', 'notes': notes,
      });

      for (final it in items) {
        final prows = await tx.query('products', where: 'id = ?', whereArgs: [it.productId], limit: 1);
        if (prows.isEmpty) throw AppException('product missing ${it.productId}');
        final p = Product.fromRow(prows.first);
        await tx.insert('purchase_items', {
          'purchase_id': purchaseId, 'product_id': it.productId,
          'name_ar': p.nameAr, 'name_fr': p.nameFr, 'qty': it.qty,
          'unit_cost_c': it.unitCostC, 'total_c': it.qty * it.unitCostC,
        });
        final nb = p.stockQty + it.qty;
        await tx.update('products', {
          'stock_qty': nb, 'updated_at': now,
          if (updateCostPrices) 'cost_c': it.unitCostC,
        }, where: 'id = ?', whereArgs: [it.productId]);
        await inventory.moveStock(tx,
            productId: it.productId, type: 'in', qty: it.qty, balanceAfter: nb,
            refType: 'purchase', refId: purchaseId, unitCostC: it.unitCostC,
            note: invoiceNo);
      }

      if (total > paid) {
        await tx.rawUpdate('UPDATE suppliers SET balance_c = balance_c + ? WHERE id = ?',
            [total - paid, supplierId]);
      }
      if (paid > 0) {
        await tx.insert('payments', {
          'direction': 'purchase', 'ref_id': purchaseId, 'party_id': supplierId,
          'amount_c': paid, 'method': 'cash', 'kind': 'payment', 'paid_at': now, 'notes': notes,
        });
      }

      await tx.insert('invoices', {
        'number': invoiceNo, 'type': 'purchase', 'ref_id': purchaseId,
        'issued_at': now, 'total_c': total, 'status': 'open',
      });
      await tx.insert('audit_logs', {
        'action': 'purchase_create', 'entity': 'purchases', 'entity_id': purchaseId,
        'details': invoiceNo, 'actor': 'local', 'logged_at': now,
      });
      return purchaseId;
    });
  }
}

/// ---------------------------------------------------------------------------
/// Expenses
/// ---------------------------------------------------------------------------
class ExpensesRepo {
  ExpensesRepo(this.db);
  final AppDatabase db;

  Future<List<(String, String, String)>> categories() async {
    final rows = await db.db.query('expense_categories');
    return rows.map((r) => (r['key'] as String, r['name_ar'] as String, r['name_fr'] as String)).toList();
  }

  Future<int> add({
    required String categoryKey,
    required String description,
    required int amountC,
    required String paidAt,
    required String method,
    String? receiptPath,
    String notes = '',
  }) async {
    final rows = await db.db.query('expense_categories', where: 'key = ?', whereArgs: [categoryKey], limit: 1);
    if (rows.isEmpty) throw AppException('category');
    return db.db.insert('expenses', {
      'category_id': rows.first['id'], 'description': description,
      'amount_c': amountC, 'paid_at': paidAt, 'method': method,
      'receipt_path': receiptPath, 'notes': notes,
    });
  }

  Future<int> remove(int id) => db.db.delete('expenses', where: 'id = ?', whereArgs: [id]);

  Future<List<Expense>> list({String from = '', String to = ''}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (from.isNotEmpty) {
      where.add('e.paid_at >= ?');
      args.add(from);
    }
    if (to.isNotEmpty) {
      where.add('e.paid_at <= ?');
      args.add(to);
    }
    final rows = await db.db.rawQuery('''
      SELECT e.*, c.key AS cat_key, c.name_fr AS cat_fr, c.name_ar AS cat_ar
      FROM expenses e JOIN expense_categories c ON c.id = e.category_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY e.id DESC LIMIT 1000''', args);
    return rows.map(Expense.fromRow).toList();
  }

  Future<int> totalC(String from, String to) async =>
      firstIntValue(await db.db.rawQuery(
          'SELECT COALESCE(SUM(amount_c),0) FROM expenses WHERE paid_at >= ? AND paid_at <= ?',
          [from, to])) ?? 0;

  /// Monthly totals for the last 12 months: (yyyy-MM, cents).
  Future<List<MapEntry<String, int>>> monthly(int months) async {
    final rows = await db.db.rawQuery('''
      SELECT substr(paid_at, 1, 7) AS ym, SUM(amount_c) AS s
      FROM expenses GROUP BY ym ORDER BY ym DESC LIMIT ?''', [months]);
    return rows.map((r) => MapEntry(r['ym'] as String, (r['s'] as int?) ?? 0)).toList();
  }
}

/// ---------------------------------------------------------------------------
/// Cash registers (daily cash sessions)
/// ---------------------------------------------------------------------------
class CashRepo {
  CashRepo(this.db);
  final AppDatabase db;

  Future<CashRegister?> openRegister() async {
    final rows = await db.db.query('cash_registers',
        where: "status = 'open'", orderBy: 'id DESC', limit: 1);
    return rows.isEmpty ? null : CashRegister.fromRow(rows.first);
  }

  Future<int> open(int openingC) async {
    final existing = await openRegister();
    if (existing != null) throw AppException('register already open');
    return db.db.insert('cash_registers', {
      'opened_at': Dates.iso(DateTime.now()), 'opening_c': openingC, 'status': 'open',
    });
  }

  /// Expected cash since opening: float + cash sales receipts
  /// + customer cash payments - cash expenses - cash purchase payments - cash refunds.
  Future<int> expectedCash(int registerId) async {
    final regrows = await db.db.query('cash_registers', where: 'id = ?', whereArgs: [registerId], limit: 1);
    if (regrows.isEmpty) return 0;
    final reg = CashRegister.fromRow(regrows.first);
    final from = reg.openedAt;
    final cashIn = firstIntValue(await db.db.rawQuery('''
      SELECT COALESCE(SUM(p.amount_c),0) FROM payments p
      WHERE p.kind='payment' AND p.method='cash' AND p.paid_at >= ?
    ''', [from])) ?? 0;
    final cashOutPay = firstIntValue(await db.db.rawQuery('''
      SELECT COALESCE(SUM(p.amount_c),0) FROM payments p
      WHERE p.kind='refund' AND p.method='cash' AND p.paid_at >= ?
    ''', [from])) ?? 0;
    final cashOutPurch = firstIntValue(await db.db.rawQuery('''
      SELECT COALESCE(SUM(pp.amount_c),0) FROM payments pp
      WHERE pp.kind='payment' AND pp.method='cash' AND pp.direction='purchase' AND pp.paid_at >= ?
    ''', [from])) ?? 0;
    final cashExp = firstIntValue(await db.db.rawQuery('''
      SELECT COALESCE(SUM(e.amount_c),0) FROM expenses e
      WHERE e.method='cash' AND e.paid_at >= ?
    ''', [from])) ?? 0;
    final cashMoves = firstIntValue(await db.db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN type='in' THEN amount_c ELSE -amount_c END),0)
      FROM cash_movements WHERE register_id = ?
    ''', [registerId])) ?? 0;
    return reg.openingC + cashIn - cashOutPay - cashOutPurch - cashExp + cashMoves;
  }

  Future<void> closeRegister(int registerId, int countedC) async {
    final expected = await expectedCash(registerId);
    await db.db.update('cash_registers', {
      'closed_at': Dates.iso(DateTime.now()),
      'closing_c': expected, 'counted_c': countedC, 'diff_c': countedC - expected,
      'status': 'closed',
    }, where: 'id = ?', whereArgs: [registerId]);
  }

  Future<List<CashRegister>> registers({int limit = 60}) async {
    final rows = await db.db.query('cash_registers', orderBy: 'id DESC', limit: limit);
    return rows.map(CashRegister.fromRow).toList();
  }

  /// adds a manual cash in/out on the open register (deposit / withdrawal).
  Future<void> manualMove({required bool cashIn, required int amountC, required String reason}) async {
    final reg = await openRegister();
    if (reg == null) throw AppException('no register');
    await db.db.insert('cash_movements', {
      'register_id': reg.id, 'type': cashIn ? 'in' : 'out', 'amount_c': amountC,
      'reason': reason, 'moved_at': Dates.iso(DateTime.now()),
    });
  }

  Future<List<CashMovement>> movements({int? registerId, int limit = 200}) async {
    final rows = await db.db.query('cash_movements',
        where: registerId != null ? 'register_id = ?' : null,
        whereArgs: registerId != null ? [registerId] : null,
        orderBy: 'id DESC', limit: limit);
    return rows.map(CashMovement.fromRow).toList();
  }
}

/// ---------------------------------------------------------------------------
/// Analytics (dashboard + reports) — all values computed from real records
/// ---------------------------------------------------------------------------
class AnalyticsRepo {
  AnalyticsRepo(this.db);
  final AppDatabase db;

  Future<int> salesSum(String from, String to) async =>
      firstIntValue(await db.db.rawQuery(
        "SELECT COALESCE(SUM(total_c),0) FROM sales WHERE status='completed' AND sale_at >= ? AND sale_at <= ?",
        [from, to])) ?? 0;

  /// Gross profit: Σ line total - unit cost, minus commission of returns.
  Future<int> grossProfitC(String from, String to) async {
    final v = firstIntValue(await db.db.rawQuery('''
      SELECT COALESCE(SUM(si.total_c - si.unit_cost_c * si.qty),0)
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status='completed' AND s.sale_at >= ? AND s.sale_at <= ?
    ''', [from, to])) ?? 0;
    final returns = firstIntValue(await db.db.rawQuery('''
      SELECT COALESCE(SUM(r.total_c),0) FROM returns r
      WHERE r.return_at >= ? AND r.return_at <= ?
    ''', [from, to])) ?? 0;
    return v - returns;
  }

  Future<int> expensesC(String from, String to) async =>
      firstIntValue(await db.db.rawQuery(
        'SELECT COALESCE(SUM(amount_c),0) FROM expenses WHERE paid_at >= ? AND paid_at <= ?',
        [from, to])) ?? 0;

  /// Net profit = gross profit - expenses (excludes capital movements).
  Future<int> netProfitC(String from, String to) async {
    final gross = await grossProfitC(from, to);
    final exp = await expensesC(from, to);
    return gross - exp;
  }

  Future<int> salesCount(String from, String to) async =>
      firstIntValue(await db.db.rawQuery(
        "SELECT COUNT(*) FROM sales WHERE status='completed' AND sale_at >= ? AND sale_at <= ?",
        [from, to])) ?? 0;

  Future<List<MapEntry<String, int>>> dailySeries(int days, String toIso) async {
    final rows = await db.db.rawQuery('''
      SELECT substr(sale_at, 1, 10) AS d, SUM(total_c) AS s, COUNT(*) AS c
      FROM sales WHERE status='completed' AND sale_at >= ?
      GROUP BY d ORDER BY d''', [Dates.iso(DateTime.parse(toIso).subtract(Duration(days: days)))]);
    return rows.map((r) => MapEntry(r['d'] as String, (r['s'] as int?) ?? 0)).toList();
  }

  Future<List<MapEntry<String, int>>> monthlySales(int months) async {
    final rows = await db.db.rawQuery('''
      SELECT substr(sale_at, 1, 7) AS ym, SUM(total_c) AS s
      FROM sales WHERE status='completed' GROUP BY ym ORDER BY ym DESC LIMIT ?''', [months]);
    return rows.map((r) => MapEntry(r['ym'] as String, (r['s'] as int?) ?? 0)).toList();
  }

  Future<List<(String, int)>> topProducts({int limitN = 8}) async {
    final rows = await db.db.rawQuery('''
      SELECT si.name_fr AS n, COALESCE(SUM(si.qty - si.returned_qty),0) AS q
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'completed'
      GROUP BY si.product_id ORDER BY q DESC LIMIT ?''', [limitN]);
    return rows.map((r) => (r['n'] as String? ?? '-', (r['q'] as int?) ?? 0)).toList();
  }

  Future<List<(String, int)>> salesByCategory() async {
    final rows = await db.db.rawQuery('''
      SELECT COALESCE(c.name_fr,'-') AS n, COALESCE(SUM(si.total_c),0) AS s
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      LEFT JOIN products p ON p.id = si.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE s.status = 'completed'
      GROUP BY si.product_id''');
    final agg = <String, int>{};
    for (final r in rows) {
      final n = r['n'] as String;
      agg[n] = (agg[n] ?? 0) + ((r['s'] as int?) ?? 0);
    }
    final list = agg.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list.take(10).map((e) => (e.key, e.value)).toList();
  }

  Future<List<(String, int)>> salesByMethod(String from, String to) async {
    final rows = await db.db.rawQuery('''
      SELECT payment_method AS m, SUM(total_c) AS s FROM sales
      WHERE status='completed' AND sale_at >= ? AND sale_at <= ?
      GROUP BY payment_method''', [from, to]);
    return rows.map((r) => (r['m'] as String, (r['s'] as int?) ?? 0)).toList();
  }

  /// (sales total, purchases total, expenses total) per month for both charts.
  Future<List<MapEntry<String, (int, int, int)>>> monthlySeries(int months) async {
    final sales = await db.db.rawQuery('''
      SELECT substr(sale_at,1,7) AS ym, SUM(total_c) AS s FROM sales
      WHERE status='completed' GROUP BY ym ORDER BY ym DESC LIMIT ?''', [months]);
    final purch = await db.db.rawQuery('''
      SELECT substr(purchase_at,1,7) AS ym, SUM(total_c) AS s FROM purchases
      GROUP BY ym ORDER BY ym DESC LIMIT ?''', [months]);
    final exp = await db.db.rawQuery('''
      SELECT substr(paid_at,1,7) AS ym, SUM(amount_c) AS s FROM expenses
      GROUP BY ym ORDER BY ym DESC LIMIT ?''', [months]);
    final map = <String, (int, int, int)>{};
    for (final r in sales) {
      final k = r['ym'] as String;
      final cur = map[k] ?? (0, 0, 0);
      map[k] = ((r['s'] as int?) ?? 0, cur.$2, cur.$3);
    }
    for (final r in purch) {
      final k = r['ym'] as String;
      final cur = map[k] ?? (0, 0, 0);
      map[k] = (cur.$1, (r['s'] as int?) ?? 0, cur.$3);
    }
    for (final r in exp) {
      final k = r['ym'] as String;
      final cur = map[k] ?? (0, 0, 0);
      map[k] = (cur.$1, cur.$2, (r['s'] as int?) ?? 0);
    }
    return map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  Future<List<Sale>> recentSales({int limit = 5}) async =>
      (await db.db.query('sales', orderBy: 'id DESC', limit: limit)).map(Sale.fromRow).toList();

  Future<List<Purchase>> recentPurchases({int limit = 5}) async =>
      (await db.db.query('purchases', orderBy: 'id DESC', limit: limit)).map(Purchase.fromRow).toList();

  Future<List<Payment>> recentPayments({int limit = 5}) =>
      (db.db.query('payments', orderBy: 'id DESC', limit: limit)).then((rows) => rows.map(Payment.fromRow).toList());

  Future<List<StockMovement>> recentMovements({int limit = 5}) =>
      InventoryRepo(db).movements(limit: limit);

  /// Product performance over range: name, qty sold, revenue, profit.
  Future<List<Map<String, Object?>>> productPerformance(String from, String to) async {
    return db.db.rawQuery('''
      SELECT si.name_fr, COALESCE(SUM(si.qty - si.returned_qty),0) AS q,
             COALESCE(SUM(si.total_c),0) AS rev,
             COALESCE(SUM(si.total_c - si.unit_cost_c*si.qty),0) AS profit
      FROM sale_items si JOIN sales s ON s.id = si.sale_id
      WHERE s.status='completed' AND s.sale_at >= ? AND s.sale_at <= ?
      GROUP BY si.product_id ORDER BY rev DESC LIMIT 100''', [from, to]);
  }

  Future<List<Map<String, Object?>>> customerReport(String from, String to) async {
    return db.db.rawQuery('''
      SELECT c.name_fr, COALESCE(SUM(s.total_c),0) AS total, COUNT(s.id) AS cnt,
             COALESCE(SUM(s.total_c - s.paid_c),0) AS due
      FROM customers c LEFT JOIN sales s ON s.customer_id = c.id
        AND s.status='completed' AND s.sale_at >= ? AND s.sale_at <= ?
      GROUP BY c.id ORDER BY total DESC LIMIT 200''', [from, to]);
  }
}
