import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

/// Products: table, editor, archive/delete, CSV import/export.
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String query = '';
  int? categoryFilter;
  bool lowOnly = false;
  bool archivedOnly = false;
  bool loading = true;
  List<Product> products = [];
  List<Category> categories = [];
  List<Brand> brands = [];
  List<Supplier> suppliers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _reload();
  }

  Future<void> _reload() async {
    final st = context.read<AppState>();
    final res = await Future.wait([
      st.catalog.products(query: query, categoryId: categoryFilter, onlyLowStock: lowOnly, includeArchived: archivedOnly),
      st.catalog.categories(),
      st.catalog.brands(),
      st.people.suppliers(),
    ]);
    if (!mounted) return;
    setState(() {
      products = res[0] as List<Product>;
      categories = res[1] as List<Category>;
      brands = res[2] as List<Brand>;
      suppliers = res[3] as List<Supplier>;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          flex: 3,
          child: SearchFieldX(hint: tr('search'), onChanged: (v) { query = v; _reload(); }),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SmartDropdown<int>(
            items: [for (final c in categories) c.id],
            value: categoryFilter,
            display: (id) => categories.firstWhere((c) => c.id == id).nameFr,
            onChanged: (v) { categoryFilter = v; _reload(); },
            label: tr('all'),
          ),
        ),
        const SizedBox(width: 10),
        ToggleButtons(
          isSelected: [lowOnly, archivedOnly],
          onPressed: (i) => setState(() {
            if (i == 0) { lowOnly = !lowOnly; if (lowOnly) archivedOnly = false; }
            else { archivedOnly = !archivedOnly; if (archivedOnly) lowOnly = false; }
          }),
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.warning_amber_rounded, size: 18, color: lowOnly ? C.warning : C.textSecondary)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.archive_outlined, size: 18, color: archivedOnly ? C.primary : C.textSecondary)),
          ],
        ),
        const Spacer(),
        AppButton(label: tr('import'), icon: Icons.upload_file_rounded, kind: AppButtonKind.ghost, onPressed: _importCsv),
        const SizedBox(width: 8),
        AppButton(label: tr('export'), icon: Icons.download_rounded, kind: AppButtonKind.ghost, onPressed: _exportCsv),
        const SizedBox(width: 8),
        AppButton(label: tr('product.new'), icon: Icons.add, onPressed: () => _edit(context, null)),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : products.isEmpty
                ? EmptyStateX(title: tr('product.none'), body: tr('product.noneHint'), icon: Icons.inventory_2_outlined,
                    action: AppButton(label: tr('product.new'), icon: Icons.add, onPressed: () => _edit(context, null)))
                : TableX(
                    columns: [tr('name'), tr('sku'), tr('category'), tr('price'), tr('pos.stock'), tr('actions')],
                    widths: [3, 1, 2, 2, 1, 2],
                    rows: [
                      for (final p in products) _row(context, p),
                    ],
                  ),
      ),
    ]);
  }

  List<Widget> _row(BuildContext context, Product p) {
    final cat = p.categoryName ?? (p.categoryId != null && categories.any((c) => c.id == p.categoryId)
        ? categories.firstWhere((c) => c.id == p.categoryId).nameFr : '—');
    final stockColor = p.stockQty <= 0 ? C.danger : (p.stockQty <= p.minStock ? C.warning : C.success);
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.name(gLocale == 'ar'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(p.sku, style: const TextStyle(fontSize: 11, color: C.textSecondary)),
      ]),
      Text(p.barcode, style: const TextStyle(fontSize: 12)),
      Text(cat, style: const TextStyle(fontSize: 12.5)),
      Text(Money.fmt(p.priceC), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.primary)),
      Text('${p.stockQty}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: stockColor)),
      Row(children: [
        IconButtonX(icon: Icons.visibility_outlined, size: 30, tooltip: tr('details'), onPressed: () => _details(context, p)),
        IconButtonX(icon: Icons.edit_outlined, size: 30, tooltip: tr('edit'), onPressed: () => _edit(context, p)),
        IconButtonX(icon: archivedOnly ? Icons.unarchive_outlined : Icons.archive_outlined, size: 30, tooltip: tr('archive'),
            onPressed: () async {
          final st = context.read<AppState>();
          await st.catalog.archiveProduct(p.id, !p.archived);
          await st.settings.audit(archivedOnly ? 'product_unarchive' : 'product_archive', 'products', p.id, p.nameFr);
          st.changed();
          _reload();
        }),
        IconButtonX(icon: Icons.delete_outline, size: 30, color: C.danger, tooltip: tr('delete'), onPressed: () => _delete(context, p)),
      ]),
    ];
  }

  Future<void> _delete(BuildContext context, Product p) async {
    final ok = await confirmDialog(context, title: '${tr('delete')} — ${p.name(gLocale == 'ar')}', body: tr('product.deleteWarn'), danger: true);
    if (!ok) return;
    final st = context.read<AppState>();
    await st.catalog.deleteProduct(p.id);
    await st.settings.audit('product_delete', 'products', p.id, p.nameFr);
    st.changed();
    _reload();
  }

  Future<void> _details(BuildContext context, Product p) async {
    final st = context.read<AppState>();
    final sold = await st.catalog.soldQuantity(p.id);
    final movements = await st.inventory.movements(productId: p.id, limit: 8);
    if (!mounted) return;
    await formDialog<void>(
      context,
      title: tr('product.details'),
      width: 640,
      body: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 84, height: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEAF0FB), Color(0xFFF3EFFC)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: p.imagePath != null && File(p.imagePath!).existsSync()
                  ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(p.imagePath!), fit: BoxFit.cover))
                  : const Icon(Icons.inventory_2_outlined, color: C.primary, size: 34),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name(gLocale == 'ar'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(p.nameAr.isNotEmpty ? p.nameAr : p.nameFr, style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 22, runSpacing: 10, children: [
            _kv(tr('sku'), p.sku), _kv(tr('barcode'), p.barcode), _kv(tr('cost'), Money.fmt(p.costC)),
            _kv(tr('price'), Money.fmt(p.priceC)), _kv(tr('wholesale'), Money.fmt(p.wholesaleC)),
            _kv(tr('pos.stock'), '${p.stockQty}'), _kv(tr('sold'), '$sold'),
          ]),
          const SizedBox(height: 14),
          Text(tr('inv.movements'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          for (final m in movements) Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Text(Dates.parse(m.movedAt).toString().substring(0, 16), style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
              const SizedBox(width: 10),
              Text(m.type == 'in' ? '+${m.qty}' : '-${m.qty}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: m.type == 'in' ? C.success : C.danger)),
              const SizedBox(width: 10),
              Expanded(child: Text(m.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
              Text('= ${m.balanceAfter}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(k, style: const TextStyle(fontSize: 11, color: C.textSecondary)),
      Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }
}
/// --------------------------------------------------------------------------
/// Products: editor + CSV
extension _ProductsOps on _ProductsPageState {
  Future<void> _edit(BuildContext context, Product? existing) async {
    final st = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProductEditor(product: existing, categories: categories, brands: brands, suppliers: suppliers, onSaved: _reload),
    );
    if (ok == true) {
      st.changed();
      _reload();
    }
  }

  Future<void> _exportCsv() async {
    final location = await getSaveLocation(suggestedName: 'products_export.csv');
    if (location == null) return;
    const header = ['id', 'name_ar', 'name_fr', 'sku', 'barcode', 'category', 'brand', 'supplier', 'cost', 'price', 'wholesale', 'stock', 'min_stock', 'max_stock', 'description'];
    final rows = <List<String>>[header];
    String catName(int? id) { for (final c in categories) { if (c.id == id) return c.nameFr; } return ''; }
    String brandName(int? id) { for (final b in brands) { if (b.id == id) return b.nameFr; } return ''; }
    String supName(int? id) { for (final s in suppliers) { if (s.id == id) return s.nameFr; } return ''; }
    for (final p in products) {
      rows.add([
        '${p.id}', p.nameAr, p.nameFr, p.sku, p.barcode,
        catName(p.categoryId), brandName(p.brandId), supName(p.supplierId),
        (p.costC / Money.centsPerUnit).toStringAsFixed(2),
        (p.priceC / Money.centsPerUnit).toStringAsFixed(2),
        (p.wholesaleC / Money.centsPerUnit).toStringAsFixed(2),
        '${p.stockQty}', '${p.minStock}', '${p.maxStock}', p.description,
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    await File(location.path).writeAsString('\ufeff$csv', flush: true);
    if (!mounted) return;
    Toasts.show(context, '${tr('export')} — ${products.length}', kind: ToastKind.success);
  }

  Future<void> _importCsv() async {
    const typeGroup = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final st = context.read<AppState>();
    try {
      final text = await file.readAsString();
      final rows = const CsvToListConverter(shouldParseNumbers: false).convert(text);
      if (rows.length < 2) throw AppException('empty file');
      final header = rows.first.map((e) => (e as String).trim().toLowerCase()).toList();
      int col(String name) => header.indexOf(name);
      final iNameAr = col('name_ar'), iNameFr = col('name_fr');
      if ((iNameAr < 0 && iNameFr < 0)) throw AppException('missing name columns');
      int k = 0;
      List<Category> cats = categories;
      for (var r = 1; r < rows.length; r++) {
        final cells = rows[r];
        String cell(int i) => i >= 0 && i < cells.length ? (cells[i]?.toString() ?? '').trim() : '';
        final nameAr = iNameAr >= 0 ? cell(iNameAr) : '';
        final nameFr = iNameFr >= 0 ? cell(iNameFr) : '';
        if (nameAr.isEmpty && nameFr.isEmpty) continue;
        int? categoryId;
        final catN = cell(col('category'));
        for (final c in cats) { if (c.nameFr == catN || c.nameAr == catN) categoryId = c.id; }
        if (catN.isNotEmpty && categoryId == null) {
          final id = await st.catalog.addCategory(catN, catN);
          cats = await st.catalog.categories();
          categoryId = id;
        }
        await st.catalog.saveProduct(Product(
          nameAr: nameAr, nameFr: nameFr,
          sku: cell(col('sku')), barcode: cell(col('barcode')),
          categoryId: categoryId,
          costC: Money.fromString(cell(col('cost'))),
          priceC: Money.fromString(cell(col('price'))),
          wholesaleC: Money.fromString(cell(col('wholesale'))),
          stockQty: int.tryParse(cell(col('stock'))) ?? 0,
          minStock: int.tryParse(cell(col('min_stock'))) ?? 5,
          maxStock: int.tryParse(cell(col('max_stock'))) ?? 0,
          description: cell(col('description')),
        ));
        k++;
      }
      await st.settings.audit('product_import', 'products', null, '$k rows');
      if (!mounted) return;
      Toasts.show(context, '${tr('import')} — $k', kind: ToastKind.success);
      st.changed();
      _reload();
    } on AppException catch (e) {
      if (!mounted) return;
      Toasts.show(context, e.message, kind: ToastKind.error);
    } catch (e) {
      if (!mounted) return;
      Toasts.show(context, '${tr('error')} CSV', kind: ToastKind.error);
    }
  }
}

/// ======================================================== product editor
class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.product, required this.categories, required this.brands, required this.suppliers, required this.onSaved});
  final Product? product;
  final List<Category> categories;
  final List<Brand> brands;
  final List<Supplier> suppliers;
  final VoidCallback onSaved;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  late final _nameAr = TextEditingController(text: widget.product?.nameAr ?? '');
  late final _nameFr = TextEditingController(text: widget.product?.nameFr ?? '');
  late final _sku = TextEditingController(text: widget.product?.sku ?? '');
  late final _barcode = TextEditingController(text: widget.product?.barcode ?? '');
  late final _cost = TextEditingController(text: widget.product == null ? '' : (widget.product!.costC / Money.centsPerUnit).toStringAsFixed(2));
  late final _price = TextEditingController(text: widget.product == null ? '' : (widget.product!.priceC / Money.centsPerUnit).toStringAsFixed(2));
  late final _wholesale = TextEditingController(text: widget.product == null ? '' : (widget.product!.wholesaleC / Money.centsPerUnit).toStringAsFixed(2));
  late final _stock = TextEditingController(text: '${widget.product?.stockQty ?? 0}');
  late final _minStock = TextEditingController(text: '${widget.product?.minStock ?? 5}');
  late final _maxStock = TextEditingController(text: '${widget.product?.maxStock ?? 0}');
  late final _descr = TextEditingController(text: widget.product?.description ?? '');
  int? categoryId;
  int? brandId;
  int? supplierId;
  String? imagePath;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final prod = widget.product;
    if (prod != null) {
      categoryId = prod.categoryId;
      brandId = prod.brandId;
      supplierId = prod.supplierId;
      imagePath = prod.imagePath;
    }
  }

  bool get _valid => _nameAr.text.trim().isNotEmpty || _nameFr.text.trim().isNotEmpty;

  Future<void> _pickImage() async {
    const typeGroup = XTypeGroup(label: 'Image', extensions: ['png', 'jpg', 'jpeg']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;
    final st = context.read<AppState>();
    final dir = Directory(p.join(p.dirname(st.dbPath), 'media'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final ext = file.path.split('.').last.toLowerCase();
    final dest = '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await File(file.path).copy(dest);
    if (!mounted) return;
    setState(() => imagePath = dest);
  }

  Future<void> _save() async {
    if (!_valid || saving) return;
    setState(() => saving = true);
    final st = context.read<AppState>();
    final p = Product(
      id: widget.product?.id ?? 0,
      nameAr: _nameAr.text.trim(), nameFr: _nameFr.text.trim(),
      sku: _sku.text.trim(), barcode: _barcode.text.trim(),
      categoryId: categoryId, brandId: brandId, supplierId: supplierId,
      costC: Money.fromString(_cost.text), priceC: Money.fromString(_price.text),
      wholesaleC: Money.fromString(_wholesale.text),
      stockQty: int.tryParse(_stock.text) ?? 0,
      minStock: int.tryParse(_minStock.text) ?? 0,
      maxStock: int.tryParse(_maxStock.text) ?? 0,
      imagePath: imagePath, description: _descr.text.trim(),
      archived: widget.product?.archived ?? false,
    );
    await st.catalog.saveProduct(p);
    await st.settings.audit(widget.product == null ? 'product_create' : 'product_update', 'products', p.id, p.nameFr);
    widget.onSaved();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 720, color: C.surface,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              child: FormHeader(title: widget.product == null ? tr('product.new') : tr('product.edit'),
                  subtitle: widget.product?.name(gLocale == 'ar')),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 92, height: 92,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF1F8),
                          border: Border.all(color: C.border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: imagePath != null && File(imagePath!).existsSync()
                            ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(imagePath!), fit: BoxFit.cover))
                            : Icon(Icons.add_photo_alternate_outlined, color: C.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(children: [
                      FieldX(controller: _nameAr, label: '${tr('name')} (AR)', onChanged: (_) => setState(() {})),
                      const SizedBox(height: 10),
                      FieldX(controller: _nameFr, label: '${tr('name')} (FR)', onChanged: (_) => setState(() {})),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: FieldX(controller: _sku, label: tr('sku'))),
                    const SizedBox(width: 10),
                    Expanded(child: FieldX(controller: _barcode, label: tr('barcode'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: SmartDropdown<int>(items: [for (final c in widget.categories) c.id], value: categoryId,
                        display: (id) => widget.categories.firstWhere((c) => c.id == id).nameFr, onChanged: (v) => setState(() => categoryId = v), label: tr('category'))),
                    const SizedBox(width: 10),
                    Expanded(child: SmartDropdown<int>(items: [for (final b in widget.brands) b.id], value: brandId,
                        display: (id) => widget.brands.firstWhere((b) => b.id == id).nameFr, onChanged: (v) => setState(() => brandId = v), label: tr('brand'))),
                    const SizedBox(width: 10),
                    Expanded(child: SmartDropdown<int>(items: [for (final s in widget.suppliers) s.id], value: supplierId,
                        display: (id) => widget.suppliers.firstWhere((s) => s.id == id).nameFr, onChanged: (v) => setState(() => supplierId = v), label: tr('supplier'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: FieldX(controller: _cost, label: tr('unitCost'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 10),
                    Expanded(child: FieldX(controller: _price, label: tr('price'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 10),
                    Expanded(child: FieldX(controller: _wholesale, label: tr('wholesale'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: FieldX(controller: _stock, label: tr('stockQty'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: FieldX(controller: _minStock, label: tr('minStock'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: FieldX(controller: _maxStock, label: tr('maxStock'), keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 10),
                  FieldX(controller: _descr, label: tr('description'), maxLines: 3),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
            FormFooter(
              submitLabel: tr('save'),
              onSubmit: _valid && !saving ? _save : () {},
            ),
          ]),
        ),
      ),
    );
  }
}
