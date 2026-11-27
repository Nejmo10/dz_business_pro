/// Domain models. All monetary fields end with `_c` and are integer centimes.
class BusinessProfile {
  BusinessProfile({
    this.name = '',
    this.activity = '',
    this.logoPath,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.language = 'ar',
    this.currency = 'DZD',
    this.taxEnabled = false,
    this.taxRate = 0,
    this.receiptFormat = 'a4',
    this.invoicePrefix = 'F',
    this.createdAt = '',
    this.updatedAt = '',
  });

  String name, activity, language, currency, receiptFormat, invoicePrefix;
  String? logoPath;
  String address, phone, email, createdAt, updatedAt;
  bool taxEnabled;
  int taxRate;

  static BusinessProfile fromRow(Map<String, Object?> r) => BusinessProfile(
        name: r['name'] as String? ?? '',
        activity: r['activity'] as String? ?? '',
        logoPath: r['logo_path'] as String?,
        address: r['address'] as String? ?? '',
        phone: r['phone'] as String? ?? '',
        email: r['email'] as String? ?? '',
        language: r['language'] as String? ?? 'ar',
        currency: r['currency'] as String? ?? 'DZD',
        taxEnabled: (r['tax_enabled'] as int? ?? 0) == 1,
        taxRate: r['tax_rate'] as int? ?? 0,
        receiptFormat: r['receipt_format'] as String? ?? 'a4',
        invoicePrefix: r['invoice_prefix'] as String? ?? 'F',
        createdAt: r['created_at'] as String? ?? '',
        updatedAt: r['updated_at'] as String? ?? '',
      );
}

class Category {
  Category({required this.id, required this.nameAr, required this.nameFr, this.count = 0});
  final int id;
  final String nameAr, nameFr;
  final int count;
  static Category fromRow(Map<String, Object?> r) => Category(
      id: r['id'] as int,
      nameAr: r['name_ar'] as String,
      nameFr: r['name_fr'] as String,
      count: r['cnt'] as int? ?? 0);
}

class Brand {
  Brand({required this.id, required this.nameAr, required this.nameFr, this.count = 0});
  final int id;
  final String nameAr, nameFr;
  final int count;
  static Brand fromRow(Map<String, Object?> r) => Brand(
      id: r['id'] as int,
      nameAr: r['name_ar'] as String,
      nameFr: r['name_fr'] as String,
      count: r['cnt'] as int? ?? 0);
}

class Product {
  Product({
    this.id = 0,
    this.nameAr = '',
    this.nameFr = '',
    this.sku = '',
    this.barcode = '',
    this.categoryId,
    this.brandId,
    this.supplierId,
    this.costC = 0,
    this.priceC = 0,
    this.wholesaleC = 0,
    this.unit = 'piece',
    this.unitsPerBox = 1,
    this.stockQty = 0,
    this.minStock = 0,
    this.maxStock = 0,
    this.imagePath,
    this.description = '',
    this.archived = false,
    this.createdAt = '',
    this.updatedAt = '',
    this.categoryName,
  });

  int id, costC, priceC, wholesaleC, stockQty, minStock, maxStock;
  int? categoryId, brandId, supplierId;
  String nameAr, nameFr, sku, barcode, description, createdAt, updatedAt;
  String unit;
  int unitsPerBox;
  String? imagePath, categoryName;
  bool archived;

  String name(bool ar) => ar ? (nameAr.isNotEmpty ? nameAr : nameFr) : (nameFr.isNotEmpty ? nameFr : nameAr);

  static Product fromRow(Map<String, Object?> r) => Product(
        id: r['id'] as int,
        nameAr: r['name_ar'] as String? ?? '',
        nameFr: r['name_fr'] as String? ?? '',
        sku: r['sku'] as String? ?? '',
        barcode: r['barcode'] as String? ?? '',
        categoryId: r['category_id'] as int?,
        brandId: r['brand_id'] as int?,
        supplierId: r['supplier_id'] as int?,
        costC: r['cost_c'] as int? ?? 0,
        priceC: r['price_c'] as int? ?? 0,
        wholesaleC: r['wholesale_c'] as int? ?? 0,
        unit: r['unit'] as String? ?? 'piece',
        unitsPerBox: r['units_per_box'] as int? ?? 1,
        stockQty: r['stock_qty'] as int? ?? 0,
        minStock: r['min_stock'] as int? ?? 0,
        maxStock: r['max_stock'] as int? ?? 0,
        imagePath: r['image_path'] as String?,
        description: r['description'] as String? ?? '',
        archived: (r['archived'] as int? ?? 0) == 1,
        createdAt: r['created_at'] as String? ?? '',
        updatedAt: r['updated_at'] as String? ?? '',
        categoryName: r['cat_name_fr'] as String?,
      );
}

class Customer {
  Customer({
    this.id = 0,
    this.nameAr = '',
    this.nameFr = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.type = 'retail',
    this.creditLimitC = 0,
    this.balanceC = 0,
    this.loyaltyPoints = 0,
    this.active = true,
    this.createdAt = '',
  });

  int id, creditLimitC, balanceC, loyaltyPoints;
  String nameAr, nameFr, phone, email, address, notes, type, createdAt;
  bool active;

  String name(bool ar) => ar ? (nameAr.isNotEmpty ? nameAr : nameFr) : (nameFr.isNotEmpty ? nameFr : nameAr);

  static Customer fromRow(Map<String, Object?> r) => Customer(
        id: r['id'] as int,
        nameAr: r['name_ar'] as String? ?? '',
        nameFr: r['name_fr'] as String? ?? '',
        phone: r['phone'] as String? ?? '',
        email: r['email'] as String? ?? '',
        address: r['address'] as String? ?? '',
        notes: r['notes'] as String? ?? '',
        type: r['type'] as String? ?? 'retail',
        creditLimitC: r['credit_limit_c'] as int? ?? 0,
        balanceC: r['balance_c'] as int? ?? 0,
        loyaltyPoints: r['loyalty_points'] as int? ?? 0,
        active: (r['active'] as int? ?? 1) == 1,
        createdAt: r['created_at'] as String? ?? '',
      );
}

class Supplier {
  Supplier({
    this.id = 0,
    this.nameAr = '',
    this.nameFr = '',
    this.company = '',
    this.contact = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.balanceC = 0,
    this.active = true,
    this.createdAt = '',
  });

  int id, balanceC;
  String nameAr, nameFr, company, contact, phone, email, address, notes, createdAt;
  bool active;

  String name(bool ar) => ar ? (nameAr.isNotEmpty ? nameAr : nameFr) : (nameFr.isNotEmpty ? nameFr : nameAr);

  static Supplier fromRow(Map<String, Object?> r) => Supplier(
        id: r['id'] as int,
        nameAr: r['name_ar'] as String? ?? '',
        nameFr: r['name_fr'] as String? ?? '',
        company: r['company'] as String? ?? '',
        contact: r['contact'] as String? ?? '',
        phone: r['phone'] as String? ?? '',
        email: r['email'] as String? ?? '',
        address: r['address'] as String? ?? '',
        notes: r['notes'] as String? ?? '',
        balanceC: r['balance_c'] as int? ?? 0,
        active: (r['active'] as int? ?? 1) == 1,
        createdAt: r['created_at'] as String? ?? '',
      );
}

class SaleItem {
  SaleItem({
    required this.productId,
    required this.qty,
    required this.unitPriceC,
    this.unitCostC = 0,
    this.discountC = 0,
    required this.totalC,
    this.nameAr = '',
    this.nameFr = '',
    this.saleId = 0,
    this.returnedQty = 0,
    this.id = 0,
  });

  int id, saleId, productId, qty, unitPriceC, unitCostC, discountC, totalC, returnedQty;
  String nameAr, nameFr;

  static SaleItem fromRow(Map<String, Object?> r) => SaleItem(
        id: r['id'] as int,
        saleId: r['sale_id'] as int,
        productId: r['product_id'] as int,
        nameAr: r['name_ar'] as String? ?? '',
        nameFr: r['name_fr'] as String? ?? '',
        qty: r['qty'] as int,
        unitPriceC: r['unit_price_c'] as int,
        unitCostC: r['unit_cost_c'] as int? ?? 0,
        discountC: r['discount_c'] as int? ?? 0,
        totalC: r['total_c'] as int,
        returnedQty: r['returned_qty'] as int? ?? 0,
      );
}

class Sale {
  Sale({
    this.id = 0,
    this.invoiceNo = '',
    this.customerId,
    this.saleAt = '',
    this.subtotalC = 0,
    this.discountC = 0,
    this.taxC = 0,
    this.totalC = 0,
    this.paidC = 0,
    this.status = 'completed',
    this.paymentMethod = 'cash',
    this.notes = '',
  });

  int id, subtotalC, discountC, taxC, totalC, paidC;
  int? customerId;
  String invoiceNo, saleAt, status, paymentMethod, notes;

  static Sale fromRow(Map<String, Object?> r) => Sale(
        id: r['id'] as int,
        invoiceNo: r['invoice_no'] as String,
        customerId: r['customer_id'] as int?,
        saleAt: r['sale_at'] as String,
        subtotalC: r['subtotal_c'] as int? ?? 0,
        discountC: r['discount_c'] as int? ?? 0,
        taxC: r['tax_c'] as int? ?? 0,
        totalC: r['total_c'] as int? ?? 0,
        paidC: r['paid_c'] as int? ?? 0,
        status: r['status'] as String? ?? 'completed',
        paymentMethod: r['payment_method'] as String? ?? 'cash',
        notes: r['notes'] as String? ?? '',
      );
}

class Purchase {
  Purchase({
    this.id = 0,
    this.invoiceNo = '',
    this.supplierId,
    this.purchaseAt = '',
    this.subtotalC = 0,
    this.discountC = 0,
    this.taxC = 0,
    this.extraCostsC = 0,
    this.totalC = 0,
    this.paidC = 0,
    this.status = 'confirmed',
    this.notes = '',
  });

  int id, subtotalC, discountC, taxC, extraCostsC, totalC, paidC;
  int? supplierId;
  String invoiceNo, purchaseAt, status, notes;

  static Purchase fromRow(Map<String, Object?> r) => Purchase(
        id: r['id'] as int,
        invoiceNo: r['invoice_no'] as String,
        supplierId: r['supplier_id'] as int?,
        purchaseAt: r['purchase_at'] as String,
        subtotalC: r['subtotal_c'] as int? ?? 0,
        discountC: r['discount_c'] as int? ?? 0,
        taxC: r['tax_c'] as int? ?? 0,
        extraCostsC: r['extra_costs_c'] as int? ?? 0,
        totalC: r['total_c'] as int? ?? 0,
        paidC: r['paid_c'] as int? ?? 0,
        status: r['status'] as String? ?? 'confirmed',
        notes: r['notes'] as String? ?? '',
      );
}

class PurchaseItem {
  PurchaseItem({required this.productId, required this.qty, required this.unitCostC, required this.totalC, this.nameAr = '', this.nameFr = ''});
  int productId, qty, unitCostC, totalC;
  String nameAr, nameFr;
}

class Expense {
  Expense({this.id = 0, this.categoryKey = '', this.categoryName = '', this.description = '', this.amountC = 0, this.paidAt = '', this.method = 'cash', this.receiptPath, this.notes = ''});
  int id, amountC;
  String categoryKey, categoryName, description, paidAt, method, notes;
  String? receiptPath;

  static Expense fromRow(Map<String, Object?> r) => Expense(
        id: r['id'] as int,
        categoryKey: r['cat_key'] as String? ?? 'other',
        categoryName: r['cat_fr'] as String? ?? '',
        description: r['description'] as String? ?? '',
        amountC: r['amount_c'] as int,
        paidAt: r['paid_at'] as String,
        method: r['method'] as String? ?? 'cash',
        receiptPath: r['receipt_path'] as String?,
        notes: r['notes'] as String? ?? '',
      );
}

class Payment {
  Payment({this.id = 0, this.direction = 'sale', this.refId = 0, this.partyId, this.amountC = 0, this.method = 'cash', this.kind = 'payment', this.paidAt = '', this.notes = ''});
  int id, refId, amountC;
  int? partyId;
  String direction, method, kind, paidAt, notes;

  static Payment fromRow(Map<String, Object?> r) => Payment(
        id: r['id'] as int,
        direction: r['direction'] as String,
        refId: r['ref_id'] as int,
        partyId: r['party_id'] as int?,
        amountC: r['amount_c'] as int,
        method: r['method'] as String,
        kind: r['kind'] as String? ?? 'payment',
        paidAt: r['paid_at'] as String,
        notes: r['notes'] as String? ?? '',
      );
}

class StockMovement {
  StockMovement({this.id = 0, this.productId = 0, this.type = '', this.qty = 0, this.balanceAfter = 0, this.refType, this.refId, this.unitCostC, this.note = '', this.movedAt = '', this.productName = ''});
  int id, productId, qty, balanceAfter;
  int? refId, unitCostC;
  String type, note, movedAt, productName;
  String? refType;

  static StockMovement fromRow(Map<String, Object?> r) => StockMovement(
        id: r['id'] as int,
        productId: r['product_id'] as int,
        type: r['type'] as String,
        qty: r['qty'] as int,
        balanceAfter: r['balance_after'] as int,
        refType: r['ref_type'] as String?,
        refId: r['ref_id'] as int?,
        unitCostC: r['unit_cost_c'] as int?,
        note: r['note'] as String? ?? '',
        movedAt: r['moved_at'] as String,
        productName: r['p_fr'] as String? ?? r['p_ar'] as String? ?? '',
      );
}

class CashRegister {
  CashRegister({this.id = 0, this.name = '', this.kind = 'cash', this.openedAt = '', this.closedAt, this.openingC = 0, this.closingC, this.countedC, this.diffC, this.status = 'open'});
  int id, openingC;
  String name, kind, openedAt;
  String? closedAt;
  int? closingC, countedC, diffC;
  String status;

  static CashRegister fromRow(Map<String, Object?> r) => CashRegister(
        id: r['id'] as int,
        name: r['name'] as String? ?? '',
        kind: r['kind'] as String? ?? 'cash',
        openedAt: r['opened_at'] as String,
        closedAt: r['closed_at'] as String?,
        openingC: r['opening_c'] as int? ?? 0,
        closingC: r['closing_c'] as int?,
        countedC: r['counted_c'] as int?,
        diffC: r['diff_c'] as int?,
        status: r['status'] as String? ?? 'open',
      );
}

class CashMovement {
  CashMovement({this.id = 0, this.registerId = 0, this.type = '', this.amountC = 0, this.reason = '', this.ref = '', this.movedAt = ''});
  int id, registerId, amountC;
  String type, reason, ref, movedAt;

  static CashMovement fromRow(Map<String, Object?> r) => CashMovement(
        id: r['id'] as int,
        registerId: r['register_id'] as int,
        type: r['type'] as String,
        amountC: r['amount_c'] as int,
        reason: r['reason'] as String? ?? '',
        ref: r['ref'] as String? ?? '',
        movedAt: r['moved_at'] as String,
      );
}

class AuditEntry {
  AuditEntry({this.id = 0, this.action = '', this.entity = '', this.entityId, this.details = '', this.actor = '', this.loggedAt = ''});
  int id;
  int? entityId;
  String action, entity, details, actor, loggedAt;

  static AuditEntry fromRow(Map<String, Object?> r) => AuditEntry(
        id: r['id'] as int,
        action: r['action'] as String,
        entity: r['entity'] as String,
        entityId: r['entity_id'] as int?,
        details: r['details'] as String? ?? '',
        actor: r['actor'] as String? ?? '',
        loggedAt: r['logged_at'] as String,
      );
}

class ReturnRec {
  ReturnRec({this.id = 0, this.returnNo = '', this.saleId = 0, this.customerId, this.returnAt = '', this.totalC = 0, this.refundedC = 0, this.reason = ''});
  int id, saleId, totalC, refundedC;
  int? customerId;
  String returnNo, returnAt, reason;
}

class CheckRec {
  CheckRec({this.id = 0, this.direction = 'received', this.party = '', this.amountC = 0, this.checkNo = '', this.bank = '', this.issuedAt = '', this.dueDate = '', this.status = 'pending', this.notes = ''});
  int id, amountC;
  String direction, party, checkNo, bank, issuedAt, dueDate, status, notes;

  static CheckRec fromRow(Map<String, Object?> r) => CheckRec(
        id: r['id'] as int,
        direction: r['direction'] as String? ?? 'received',
        party: r['party'] as String? ?? '',
        amountC: r['amount_c'] as int? ?? 0,
        checkNo: r['check_no'] as String? ?? '',
        bank: r['bank'] as String? ?? '',
        issuedAt: r['issued_at'] as String? ?? '',
        dueDate: r['due_date'] as String? ?? '',
        status: r['status'] as String? ?? 'pending',
        notes: r['notes'] as String? ?? '',
      );
}

class AdvanceRec {
  AdvanceRec({this.id = 0, this.employee = '', this.amountC = 0, this.settledC = 0, this.takenAt = '', this.settledAt, this.status = 'open', this.notes = ''});
  int id, amountC, settledC;
  String employee, takenAt, status, notes;
  String? settledAt;

  static AdvanceRec fromRow(Map<String, Object?> r) => AdvanceRec(
        id: r['id'] as int,
        employee: r['employee'] as String? ?? '',
        amountC: r['amount_c'] as int? ?? 0,
        settledC: r['settled_c'] as int? ?? 0,
        takenAt: r['taken_at'] as String? ?? '',
        settledAt: r['settled_at'] as String?,
        status: r['status'] as String? ?? 'open',
        notes: r['notes'] as String? ?? '',
      );
}
