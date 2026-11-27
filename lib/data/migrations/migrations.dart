import 'package:sqflite_common/sqlite_api.dart';

/// Forward-only schema migrations. Each version's SQL is idempotent-safe:
/// CREATE TABLE IF NOT EXISTS / CREATE INDEX IF NOT EXISTS, so replaying a
/// version never destroys user data.
class Migrations {
  static const Map<int, List<String>> _scripts = <int, List<String>>{
    2: [
      "ALTER TABLE products ADD COLUMN unit TEXT NOT NULL DEFAULT 'piece'",
      'ALTER TABLE products ADD COLUMN units_per_box INTEGER NOT NULL DEFAULT 1',
      'ALTER TABLE customers ADD COLUMN loyalty_points INTEGER NOT NULL DEFAULT 0',
      "ALTER TABLE cash_registers ADD COLUMN name TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE cash_registers ADD COLUMN kind TEXT NOT NULL DEFAULT 'cash'",
      _checks,
      _advances,
    ],
  };

  static List<String> get createScript => [
    _settings,
    _businessProfile,
    _users,
    _categories,
    _brands,
    _expenseCategories,
    _products,
    _customers,
    _suppliers,
    _sales,
    _saleItems,
    _purchases,
    _purchaseItems,
    _returns,
    _returnItems,
    _invoices,
    _payments,
    _expenses,
    _stockMovements,
    _cashRegisters,
    _cashMovements,
    _auditLogs,
    _checks,
    _advances,
  ];

  static const String _settings = '''
  CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )''';

  static const String _businessProfile = '''
  CREATE TABLE IF NOT EXISTS business_profile (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    name TEXT NOT NULL,
    activity TEXT,
    logo_path TEXT,
    address TEXT,
    phone TEXT,
    email TEXT,
    language TEXT NOT NULL DEFAULT 'ar',
    currency TEXT NOT NULL DEFAULT 'DZD',
    tax_enabled INTEGER NOT NULL DEFAULT 0,
    tax_rate INTEGER NOT NULL DEFAULT 0,
    receipt_format TEXT NOT NULL DEFAULT 'a4',
    invoice_prefix TEXT NOT NULL DEFAULT 'F',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''';

  static const String _users = '''
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'cashier',
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
  )''';

  static const String _categories = '''
  CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name_ar TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    parent_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL
  )''';

  static const String _brands = '''
  CREATE TABLE IF NOT EXISTS brands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name_ar TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    created_at TEXT NOT NULL
  )''';

  static const String _expenseCategories = '''
  CREATE TABLE IF NOT EXISTS expense_categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    name_ar TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    created_at TEXT NOT NULL
  )''';

  static const String _products = '''
  CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name_ar TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    sku TEXT UNIQUE,
    barcode TEXT,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    brand_id INTEGER REFERENCES brands(id) ON DELETE SET NULL,
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
    cost_c INTEGER NOT NULL DEFAULT 0,
    price_c INTEGER NOT NULL DEFAULT 0,
    wholesale_c INTEGER NOT NULL DEFAULT 0,
    unit TEXT NOT NULL DEFAULT 'piece',
    units_per_box INTEGER NOT NULL DEFAULT 1,
    stock_qty INTEGER NOT NULL DEFAULT 0,
    min_stock INTEGER NOT NULL DEFAULT 0,
    max_stock INTEGER NOT NULL DEFAULT 0,
    image_path TEXT,
    description TEXT,
    archived INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''';

  static const String _customers = '''
  CREATE TABLE IF NOT EXISTS customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name_ar TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    address TEXT,
    notes TEXT,
    type TEXT NOT NULL DEFAULT 'retail',
    credit_limit_c INTEGER NOT NULL DEFAULT 0,
    balance_c INTEGER NOT NULL DEFAULT 0,
    loyalty_points INTEGER NOT NULL DEFAULT 0,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
  )''';

  static const String _suppliers = '''
  CREATE TABLE IF NOT EXISTS suppliers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name_ar TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    company TEXT,
    contact TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    notes TEXT,
    balance_c INTEGER NOT NULL DEFAULT 0,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
  )''';

  static const String _sales = '''
  CREATE TABLE IF NOT EXISTS sales (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_no TEXT NOT NULL UNIQUE,
    customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
    sale_at TEXT NOT NULL,
    subtotal_c INTEGER NOT NULL DEFAULT 0,
    discount_c INTEGER NOT NULL DEFAULT 0,
    tax_c INTEGER NOT NULL DEFAULT 0,
    total_c INTEGER NOT NULL DEFAULT 0,
    paid_c INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'completed',
    payment_method TEXT NOT NULL DEFAULT 'cash',
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    notes TEXT
  )''';

  static const String _saleItems = '''
  CREATE TABLE IF NOT EXISTS sale_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    name_ar TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    qty INTEGER NOT NULL,
    unit_price_c INTEGER NOT NULL,
    unit_cost_c INTEGER NOT NULL DEFAULT 0,
    discount_c INTEGER NOT NULL DEFAULT 0,
    total_c INTEGER NOT NULL,
    returned_qty INTEGER NOT NULL DEFAULT 0
  )''';

  static const String _purchases = '''
  CREATE TABLE IF NOT EXISTS purchases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_no TEXT NOT NULL UNIQUE,
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
    purchase_at TEXT NOT NULL,
    subtotal_c INTEGER NOT NULL DEFAULT 0,
    discount_c INTEGER NOT NULL DEFAULT 0,
    tax_c INTEGER NOT NULL DEFAULT 0,
    extra_costs_c INTEGER NOT NULL DEFAULT 0,
    total_c INTEGER NOT NULL DEFAULT 0,
    paid_c INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'confirmed',
    notes TEXT
  )''';

  static const String _purchaseItems = '''
  CREATE TABLE IF NOT EXISTS purchase_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    name_ar TEXT NOT NULL,
    name_fr TEXT NOT NULL,
    qty INTEGER NOT NULL,
    unit_cost_c INTEGER NOT NULL,
    total_c INTEGER NOT NULL
  )''';

  static const String _returns = '''
  CREATE TABLE IF NOT EXISTS returns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    return_no TEXT NOT NULL UNIQUE,
    sale_id INTEGER NOT NULL REFERENCES sales(id),
    customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
    return_at TEXT NOT NULL,
    total_c INTEGER NOT NULL DEFAULT 0,
    refunded_c INTEGER NOT NULL DEFAULT 0,
    reason TEXT,
    notes TEXT
  )''';

  static const String _returnItems = '''
  CREATE TABLE IF NOT EXISTS return_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    return_id INTEGER NOT NULL REFERENCES returns(id) ON DELETE CASCADE,
    sale_item_id INTEGER NOT NULL REFERENCES sale_items(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    qty INTEGER NOT NULL,
    unit_price_c INTEGER NOT NULL,
    total_c INTEGER NOT NULL
  )''';

  static const String _invoices = '''
  CREATE TABLE IF NOT EXISTS invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    number TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL,
    ref_id INTEGER NOT NULL,
    issued_at TEXT NOT NULL,
    total_c INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'open'
  )''';

  static const String _payments = '''
  CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    direction TEXT NOT NULL,
    ref_id INTEGER NOT NULL,
    party_id INTEGER,
    amount_c INTEGER NOT NULL,
    method TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'payment',
    paid_at TEXT NOT NULL,
    notes TEXT
  )''';

  static const String _expenses = '''
  CREATE TABLE IF NOT EXISTS expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id INTEGER NOT NULL REFERENCES expense_categories(id),
    description TEXT NOT NULL,
    amount_c INTEGER NOT NULL,
    paid_at TEXT NOT NULL,
    method TEXT NOT NULL DEFAULT 'cash',
    receipt_path TEXT,
    notes TEXT
  )''';

  static const String _stockMovements = '''
  CREATE TABLE IF NOT EXISTS stock_movements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL REFERENCES products(id),
    type TEXT NOT NULL,
    qty INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    ref_type TEXT,
    ref_id INTEGER,
    unit_cost_c INTEGER,
    note TEXT,
    moved_at TEXT NOT NULL
  )''';

  static const String _cashRegisters = '''
  CREATE TABLE IF NOT EXISTS cash_registers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL DEFAULT '',
    kind TEXT NOT NULL DEFAULT 'cash',
    opened_at TEXT NOT NULL,
    closed_at TEXT,
    opening_c INTEGER NOT NULL DEFAULT 0,
    closing_c INTEGER,
    counted_c INTEGER,
    diff_c INTEGER,
    status TEXT NOT NULL DEFAULT 'open'
  )''';

  static const String _checks = '''
  CREATE TABLE IF NOT EXISTS checks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    direction TEXT NOT NULL,
    party TEXT NOT NULL DEFAULT '',
    amount_c INTEGER NOT NULL DEFAULT 0,
    check_no TEXT,
    bank TEXT,
    issued_at TEXT NOT NULL,
    due_date TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    register_id INTEGER REFERENCES cash_registers(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TEXT NOT NULL
  )''';

  static const String _advances = '''
  CREATE TABLE IF NOT EXISTS advances (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    employee TEXT NOT NULL,
    amount_c INTEGER NOT NULL,
    settled_c INTEGER NOT NULL DEFAULT 0,
    taken_at TEXT NOT NULL,
    settled_at TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    notes TEXT,
    created_at TEXT NOT NULL
  )''';

  static const String _cashMovements = '''
  CREATE TABLE IF NOT EXISTS cash_movements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    register_id INTEGER NOT NULL REFERENCES cash_registers(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    amount_c INTEGER NOT NULL,
    reason TEXT,
    ref TEXT,
    moved_at TEXT NOT NULL
  )''';

  static const String _auditLogs = '''
  CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    entity TEXT NOT NULL,
    entity_id INTEGER,
    details TEXT,
    actor TEXT,
    logged_at TEXT NOT NULL
  )''';

  static List<String> get indexScript => const [
    'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)',
    'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)',
    'CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku)',
    'CREATE INDEX IF NOT EXISTS idx_sales_at ON sales(sale_at)',
    'CREATE INDEX IF NOT EXISTS idx_sales_customer ON sales(customer_id)',
    'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)',
    'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id)',
    'CREATE INDEX IF NOT EXISTS idx_purchases_at ON purchases(purchase_at)',
    'CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase ON purchase_items(purchase_id)',
    'CREATE INDEX IF NOT EXISTS idx_payments_ref ON payments(direction, ref_id)',
    'CREATE INDEX IF NOT EXISTS idx_payments_party ON payments(direction, party_id)',
    'CREATE INDEX IF NOT EXISTS idx_expenses_at ON expenses(paid_at)',
    'CREATE INDEX IF NOT EXISTS idx_stock_mov_product ON stock_movements(product_id)',
    'CREATE INDEX IF NOT EXISTS idx_stock_mov_at ON stock_movements(moved_at)',
    'CREATE INDEX IF NOT EXISTS idx_invoices_at ON invoices(issued_at)',
    'CREATE INDEX IF NOT EXISTS idx_returns_sale ON returns(sale_id)',
    'CREATE INDEX IF NOT EXISTS idx_cash_mov_register ON cash_movements(register_id)',
    'CREATE INDEX IF NOT EXISTS idx_audit_at ON audit_logs(logged_at)',
    'CREATE INDEX IF NOT EXISTS idx_checks_due ON checks(due_date)',
  ];

  static const Map<int, List<String>> seedScript = {
    1: [
      "INSERT OR IGNORE INTO expense_categories(key, name_ar, name_fr, created_at) VALUES"
          " ('rent','إيجار','Loyer', COALESCE((SELECT strftime('%Y-%m-%dT%H:%M:%S','now')),'2026-01-01T00:00:00')), "
          " ('electricity','كهرباء','Électricité','2026-01-01T00:00:00'), "
          " ('internet','إنترنت','Internet','2026-01-01T00:00:00'), "
          " ('salaries','أجور','Salaires','2026-01-01T00:00:00'), "
          " ('transport','نقل ومواصلات','Transport','2026-01-01T00:00:00'), "
          " ('maintenance','صيانة','Entretien','2026-01-01T00:00:00'), "
          " ('other','أخرى','Autres','2026-01-01T00:00:00')",
      "INSERT OR IGNORE INTO app_settings(key,value) VALUES ('schema_seeded','1'),"
          " ('allow_negative_stock','0'), ('backup_on_close','0'), ('sale_counter','0'), ('purchase_counter','0'), ('return_counter','0')",
    ],
  };

  /// Initial creation of a fresh database at [version].
  static Future<void> createAll(Database db, int version) async {
    await db.transaction((tx) async {
      for (final stmt in createScript) {
        await tx.execute(stmt);
      }
      for (final stmt in indexScript) {
        await tx.execute(stmt);
      }
      for (final stmt in seedFor(version)) {
        await tx.execute(stmt);
      }
    });
  }

  /// Seed rows for every version <= [version] (INSERT OR IGNORE: safe to
  /// replay, so fresh installs at a higher version still get earlier seeds).
  static List<String> seedFor(int version) => [
    for (final e in seedScript.entries)
      if (e.key <= version) ...e.value,
  ];

  /// Applies forward migrations from [from] (old version) to [to].
  static Future<void> migrate(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      final stmts = _scripts[v] ?? seedScript[v] ?? const <String>[];
      await db.transaction((tx) async {
        for (final s in stmts) {
          await tx.execute(s);
        }
      });
    }
  }

  /// Lightweight structural verification: every expected table must exist.
  static Future<void> verifyIntegrity(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final present = rows.map((r) => r['name'] as String).toSet();
    final required = <String>{
      'app_settings', 'business_profile', 'users', 'categories', 'brands',
      'expense_categories', 'products', 'customers', 'suppliers', 'sales',
      'sale_items', 'purchases', 'purchase_items', 'returns', 'return_items',
      'invoices', 'payments', 'expenses', 'stock_movements', 'cash_registers',
      'cash_movements', 'audit_logs', 'checks', 'advances',
    };
    final missing = required.difference(present);
    if (missing.isNotEmpty) {
      throw StateError('Database schema incomplete: missing $missing');
    }
  }
}
