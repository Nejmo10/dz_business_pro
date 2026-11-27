import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

/// Purchases: new purchase editor, list, payables.
class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});
  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  String query = '';
  bool loading = true;
  List<Purchase> purchases = [];
  List<Supplier> suppliers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _reload();
  }

  String? loadError;

  Future<void> _reload() async {
    final st = context.read<AppState>();
    try {
      final res = await Future.wait([
        st.purchases.purchases(),
        st.people.suppliers(),
      ]);
      if (!mounted) return;
      setState(() {
        final list = res[0] as List<Purchase>;
        suppliers = List<Supplier>.from(res[1] as List<Supplier>);
        purchases = query.isEmpty ? list : list.where((p) =>
            p.invoiceNo.toLowerCase().contains(query.toLowerCase()) ||
            _supplierName(p.supplierId).toLowerCase().contains(query.toLowerCase())).toList();
        loading = false;
        loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; loadError = '$e'; });
    }
  }

  String _supplierName(int? id) {
    for (final s in suppliers) { if (s.id == id) return s.name(gLocale == 'ar'); }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final payables = purchases.fold<int>(0, (s, p) => s + (p.totalC > p.paidC ? p.totalC - p.paidC : 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(flex: 3, child: SearchFieldX(hint: tr('search'), onChanged: (v) { query = v; _reload(); })),
        const SizedBox(width: 10),
        Text('${tr('supp.balance')}: ', style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
        Text(Money.fmt(payables), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.danger)),
        const Spacer(),
        AppButton(label: tr('purchase.new'), icon: Icons.local_shipping_rounded, onPressed: () => _newPurchase(context)),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? ErrorStateX(message: loadError!, onRetry: _reload)
            : purchases.isEmpty
                ? EmptyStateX(title: tr('purchase.none'), body: tr('purchase.noneHint'), icon: Icons.local_shipping_outlined)
                : TableX(
                    columns: [tr('reference'), tr('supplier'), tr('date'), tr('total'), tr('paid'), tr('remaining'), tr('actions')],
                    widths: [2, 3, 2, 2, 2, 2, 1],
                    rows: [for (final p in purchases) _row(context, p)],
                  ),
      ),
    ]);
  }

  List<Widget> _row(BuildContext context, Purchase p) {
    final due = p.totalC > p.paidC ? p.totalC - p.paidC : 0;
    return [
      Text(p.invoiceNo, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.primary)),
      Text(_supplierName(p.supplierId), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
      Text(p.purchaseAt.substring(0, 10), style: const TextStyle(fontSize: 12)),
      Text(Money.fmt(p.totalC), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      Text(Money.fmt(p.paidC), style: const TextStyle(fontSize: 12.5, color: C.success)),
      Text(due > 0 ? Money.fmt(due) : '—', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: due > 0 ? C.danger : C.textSecondary)),
      Row(children: [
        IconButtonX(icon: Icons.payments_outlined, size: 30, color: C.success, tooltip: tr('payment.addPayment'), onPressed: () => _pay(context, p)),
        IconButtonX(icon: Icons.remove_red_eye_outlined, size: 30, tooltip: tr('details'), onPressed: () => _details(context, p)),
      ]),
    ];
  }

  Future<void> _pay(BuildContext context, Purchase p) async {
    final st = context.read<AppState>();
    final c1 = TextEditingController();
    String method = 'cash';
    await formDialog<bool>(context, width: 420, title: '${tr('payment.paidTo')} — ${p.invoiceNo}', body: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Column(children: [
            _kvRow(tr('total'), Money.fmt(p.totalC), C.textPrimary),
            _kvRow(tr('paid'), Money.fmt(p.paidC), C.success),
            _kvRow(tr('remaining'), Money.fmt(p.totalC - p.paidC), C.danger),
            FieldX(controller: c1, label: tr('amount'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 10),
            Wrap(spacing: 4, children: [
              for (final m in const ['cash', 'card', 'transfer'])
                Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
                  label: Text(m == 'cash' ? tr('cash') : m == 'card' ? tr('card') : tr('transfer')),
                  selected: method == m,
                  onSelected: (_) => setD(() => method = m),
                )),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        FormFooter(onSubmit: () async {
          if (Money.fromString(c1.text) <= 0) {
            Toasts.show(ctx, tr('requiredField'), kind: ToastKind.warning);
            return;
          }
          await st.people.recordPayment(direction: 'purchase', refId: p.id, partyId: p.supplierId,
              amountC: Money.fromString(c1.text), method: method, notes: p.invoiceNo);
          await st.settings.audit('purchase_payment', 'purchases', p.id, p.invoiceNo);
          if (ctx.mounted) Navigator.pop(ctx, true);
          st.changed();
          _reload();
        }),
      ]),
    ));
  }

  Widget _kvRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: C.textSecondary))),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Future<void> _details(BuildContext context, Purchase p) async {
    final st = context.read<AppState>();
    final items = await st.purchases.purchaseItems(p.id);
    if (!mounted) return;
    await formDialog<void>(context, title: '${tr('purchase.new')} — ${p.invoiceNo}', width: 640, body: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${_supplierName(p.supplierId)} · ${p.purchaseAt.substring(0, 10)} · ${p.notes}', style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
        const SizedBox(height: 12),
        for (final it in items) Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(it.nameFr.isNotEmpty ? it.nameFr : it.nameAr, style: const TextStyle(fontSize: 12.5))),
            Text('x${it.qty}', style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            const SizedBox(width: 14),
            Text(Money.fmt(it.unitCostC), style: const TextStyle(fontSize: 12.5)),
            const Spacer(),
            Text(Money.fmt(it.totalC), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (p.extraCostsC > 0 || p.discountC > 0 || p.taxC > 0) ...[
          const Divider(height: 18),
          _kvRow(tr('discount'), Money.fmt(p.discountC), C.textSecondary),
          if (p.extraCostsC > 0) _kvRow(tr('purchase.extra'), Money.fmt(p.extraCostsC), C.textSecondary),
          if (p.taxC > 0) _kvRow(tr('tax'), Money.fmt(p.taxC), C.textSecondary),
        ],
        const SizedBox(height: 20),
      ]),
    ));
  }

  Future<void> _newPurchase(BuildContext context) async {
    final st = context.read<AppState>();
    if (suppliers.isEmpty) {
      Toasts.show(context, tr('sup.none'), kind: ToastKind.warning);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PurchaseEditor(suppliers: suppliers, onDone: () { st.changed(); _reload(); }),
    );
    if (ok == true) {
      st.changed();
      _reload();
    }
  }

}

/// ======================================================== purchase editor
class _PLine {
  _PLine(this.product);
  Product product;
  int qty = 1;
  int costC = 0;
  final ctrl = TextEditingController();
}

class PurchaseEditor extends StatefulWidget {
  const PurchaseEditor({super.key, required this.suppliers, required this.onDone});
  final List<Supplier> suppliers;
  final VoidCallback onDone;

  @override
  State<PurchaseEditor> createState() => _PurchaseEditorState();
}

class _PurchaseEditorState extends State<PurchaseEditor> {
  int? supplierId;
  final _discount = TextEditingController(text: '0');
  final _extra = TextEditingController(text: '0');
  final _paid = TextEditingController(text: '0');
  String method = 'cash';
  bool updateCosts = true;
  final _pickerQuery = TextEditingController();
  String pickerQuery = '';
  bool saving = false;
  final Map<int, _PLine> lines = {};
  List<Product> products = [];
  List<Category> cats = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (products.isEmpty) _load();
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    products = await st.catalog.products();
    cats = await st.catalog.categories();
    if (mounted) setState(() {});
  }

  List<Product> get _filtered {
    if (pickerQuery.isEmpty) return products;
    final q = pickerQuery.toLowerCase();
    return products.where((p) =>
        p.nameAr.toLowerCase().contains(q) ||
        p.nameFr.toLowerCase().contains(q) ||
        p.sku.toLowerCase().contains(q) ||
        p.barcode.contains(q)).toList();
  }

  int get _subtotalC => lines.values.fold(0, (s, l) => s + l.qty * l.costC);

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final extra = Money.fromString(_extra.text);
    final discount = Money.fromString(_discount.text);
    final taxEnabled = st.profile.taxEnabled;
    final taxRate = st.profile.taxRate;
    final taxable = ((_subtotalC - discount).clamp(0, _subtotalC)).toInt();
    final taxC = taxEnabled ? (taxable * taxRate / 100).round() : 0;
    final total = taxable + taxC + extra;
    final paid = Money.fromString(_paid.text).clamp(0, total).toInt();
    return Dialog(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 860,
          height: 660,
          color: C.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Stack(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                child: FormHeader(title: tr('purchase.new'), subtitle: tr('purchase.hint')),
              ),
              PositionedDirectional(
                top: 10,
                end: 10,
                child: IconButtonX(
                  icon: Icons.close_rounded,
                  size: 34,
                  tooltip: tr('close'),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
            ]),
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 0, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _pickerQuery,
                          onChanged: (v) => setState(() => pickerQuery = v),
                          decoration: InputDecoration(hintText: tr('search'), prefixIcon: const Icon(Icons.search, size: 19)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final p = _filtered[i];
                            final inCart = lines[p.id];
                            return InkWell(
                              onTap: () => setState(() {
                                final line = lines[p.id];
                                if (line == null) {
                                  lines[p.id] = _PLine(p)
                                    ..costC = p.costC
                                    ..ctrl.text = (p.costC / Money.centsPerUnit).toStringAsFixed(2);
                                } else {
                                  line.qty += 1;
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 5),
                                decoration: BoxDecoration(
                                  color: inCart != null ? C.primary.withValues(alpha: .06) : null,
                                  border: Border.all(color: inCart != null ? C.primary.withValues(alpha: .45) : C.border),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(children: [
                                  Expanded(child: Text(p.name(gLocale == 'ar'), maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                  Text('${tr('pos.stock')} ${p.stockQty}', style: const TextStyle(fontSize: 11, color: C.textSecondary)),
                                  if (inCart != null) ...[
                                    const SizedBox(width: 10),
                                    BadgeX(text: 'x${inCart.qty}', color: C.primary),
                                  ],
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 22, 14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SmartDropdown<int>(items: [for (final s in widget.suppliers) s.id], value: supplierId,
                          display: (id) => widget.suppliers.firstWhere((s) => s.id == id).name(gLocale == 'ar'),
                          onChanged: (v) => setState(() => supplierId = v), label: tr('supplier')),
                      const SizedBox(height: 10),
                      Expanded(
                        child: lines.isEmpty
                            ? EmptyStateX(title: tr('purchase.empty'), body: '', icon: Icons.inventory_2_outlined)
                            : ListView(children: [
                                for (final line in lines.values) Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(10)),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(line.product.name(gLocale == 'ar'), maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      Row(children: [
                                        _qtyBtn(Icons.remove, () => setState(() {
                                          line.qty = ((line.qty - 1).clamp(1, 99999)).toInt();
                                        })),
                                        Text('  ${line.qty}  ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                        _qtyBtn(Icons.add, () => setState(() => line.qty = (line.qty + 1).clamp(1, 99999))),
                                        const Spacer(),
                                        SizedBox(width: 110, child: TextField(
                                          controller: line.ctrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          decoration: const InputDecoration(isDense: true),
                                          onChanged: (v) => line.costC = Money.fromString(v),
                                        )),
                                      ]),
                                    ]),
                                  ),
                                ),
                              ]),
                      ),
                      Row(children: [
                        Expanded(child: FieldX(controller: _discount, label: tr('discount'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: FieldX(controller: _extra, label: tr('purchase.extra'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 8),
                        Expanded(child: FieldX(controller: _paid, label: tr('paid'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
                      ]),
                      const SizedBox(height: 8),
                      _kvRow(tr('subtotal'), Money.fmt(_subtotalC), C.textPrimary),
                      _kvRow('${tr('tax')} ($taxRate%)', Money.fmt(taxC), C.textSecondary),
                      _kvRow(tr('total'), Money.fmt(total), C.primary),
                      _kvRow(tr('remaining'), Money.fmt(total - paid), total - paid > 0 ? C.danger : C.success),
                      const SizedBox(height: 8),
                      Wrap(spacing: 4, children: [
                        for (final m in const ['cash', 'card', 'transfer'])
                          Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
                            label: Text(m == 'cash' ? tr('cash') : m == 'card' ? tr('card') : tr('transfer')),
                            selected: method == m,
                            onSelected: (_) => setState(() => method = m),
                          )),
                        Checkbox(value: updateCosts, onChanged: (v) => setState(() => updateCosts = v ?? true)),
                        Text(tr('purchase.updateCost'), style: const TextStyle(fontSize: 11.5)),
                      ]),
                      const SizedBox(height: 10),
                      AppButton(
                        label: '${tr('purchase.confirm')} — ${Money.fmt(total)}',
                        icon: Icons.check_circle_rounded,
                        width: double.infinity,
                        onPressed: (lines.isEmpty || supplierId == null || saving) ? null : () => _confirm(st, total, paid),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 24, height: 24,
      decoration: BoxDecoration(border: Border.all(color: C.border), borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 13, color: C.textSecondary),
    ),
  );

  Widget _kvRow(String label, String value, Color color) {
    return Row(children: [
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: C.textSecondary))),
        const Spacer(),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Future<void> _confirm(AppState st, int total, int paid) async {
    setState(() => saving = true);
    final items = [
      for (final l in lines.values)
        PurchaseItem(productId: l.product.id, qty: l.qty, unitCostC: l.costC, totalC: l.qty * l.costC,
            nameAr: l.product.nameAr, nameFr: l.product.nameFr),
    ];
    try {
      final id = await st.purchases.createPurchase(
        supplierId: supplierId,
        items: items,
        discountC: Money.fromString(_discount.text),
        extraCostsC: Money.fromString(_extra.text),
        paidC: paid,
        taxEnabled: st.profile.taxEnabled,
        taxRate: st.profile.taxRate,
        updateCostPrices: updateCosts,
        notes: '',
      );
      await st.settings.audit('purchase_create', 'purchases', id, 'total=$total');
      widget.onDone();
      if (mounted) Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      Toasts.show(context, e.message, kind: ToastKind.error);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      // Show the real cause instead of a bare "error" so nothing is a mystery.
      Toasts.show(context, '${tr('error')}: $e', kind: ToastKind.error);
    }
  }
}
