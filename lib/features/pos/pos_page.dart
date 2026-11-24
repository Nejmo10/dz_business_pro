import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../printing/print_service.dart';

class CartLine {
  CartLine({required this.product, required this.qty});
  Product product;
  int qty;
}

/// Point of sale: live catalog + cart + transactional checkout.
class PosPage extends StatefulWidget {
  const PosPage({super.key});
  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final Map<int, CartLine> cart = {};
  String query = '';
  int? categoryFilter;
  int? customerId;
  List<Product> products = [];
  List<Category> categories = [];
  List<Customer> customers = const [];
  bool loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _reload();
  }

  String? loadError;

  Future<void> _reload() async {
    final st = context.read<AppState>();
    try {
      final prods = await st.catalog.products();
      final cats = await st.catalog.categories();
      final custs = await st.people.customers();
      if (!mounted) return;
      setState(() {
        products = prods;
        categories = cats;
        customers = custs;
        for (final line in cart.values) {
          for (final p in prods) {
            if (p.id == line.product.id) line.product = p;
          }
        }
        loading = false;
        loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; loadError = '$e'; });
    }
  }

  List<Product> get filtered => products.where((p) {
        if (categoryFilter != null && p.categoryId != categoryFilter) return false;
        if (query.isEmpty) return true;
        final q = query.toLowerCase();
        return p.nameAr.toLowerCase().contains(q) ||
            p.nameFr.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.barcode.contains(query);
      }).toList();

  int get subtotalC => cart.values.fold(0, (s, l) => s + l.qty * l.product.priceC);

  void addToCart(Product p, {int qty = 1}) {
    setState(() {
      final line = cart[p.id];
      if (line == null) {
        cart[p.id] = CartLine(product: p, qty: qty);
      } else {
        line.qty += qty;
      }
    });
  }

  void setQty(int productId, int qty) {
    if (qty <= 0) {
      setState(() => cart.remove(productId));
    } else {
      setState(() => cart[productId]!.qty = qty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        flex: 3,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 40,
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  onSubmitted: _barcodeScan,
                  decoration: InputDecoration(
                    hintText: tr('pos.scanBarcode'),
                    prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 19, color: C.textSecondary),
                    filled: true, fillColor: C.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 40,
                child: SmartDropdown<int>(
                  items: [for (final c in categories) c.id],
                  value: categoryFilter,
                  display: (id) => categories.firstWhere((c) => c.id == id).nameFr,
                  onChanged: (v) => setState(() => categoryFilter = v),
                  label: tr('all'),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : loadError != null
                    ? ErrorStateX(message: loadError!, onRetry: _reload)
                    : list.isEmpty
                    ? EmptyStateX(title: tr('pos.empty'), body: '', icon: Icons.inventory_2_outlined)
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 205,
                            mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 148),
                        itemCount: list.length,
                        itemBuilder: (ctx, i) => ProductCard(
                          product: list[i],
                          inCart: cart[list[i].id]?.qty ?? 0,
                          onTap: () => addToCart(list[i]),
                        ),
                      ),
          ),
        ]),
      ),
      const SizedBox(width: 14),
      SizedBox(
        width: 330,
        child: CartPanel(
          lines: cart.values.toList(),
          customerId: customerId,
          customers: customers,
          onQty: setQty,
          onCustomer: (id) => setState(() => customerId = id),
          onCheckout: _checkout,
        ),
      ),
    ]);
  }

  Future<void> _checkout() async {
    final saleId = await showDialog<int>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: CheckoutDialog(lines: cart.values.toList(), customerId: customerId, customers: customers),
        ),
      ),
    );
    if (!mounted || saleId == null || saleId <= 0) return;
    setState(() {
      cart.clear();
      customerId = null;
      loading = false;
    });
    await _reload();
    Toasts.show(context, '${tr('sale.recorded')} \u2014 ${tr('success')}', kind: ToastKind.success);
  }

  Future<void> _barcodeScan(String code) async {
    final st = context.read<AppState>();
    final p = await st.catalog.productByBarcode(code.trim());
    if (!mounted) return;
    if (p == null) {
      Toasts.show(context, tr('pos.productNotFound'), kind: ToastKind.error);
    } else {
      addToCart(p);
      Toasts.show(context, '${p.name(gLocale == 'ar')} +1');
    }
  }
}

class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.product, required this.inCart, required this.onTap});
  final Product product;
  final int inCart;
  final VoidCallback onTap;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _hover = false;

  Color get _stockColor {
    final p = widget.product;
    if (p.stockQty <= 0) return C.danger;
    if (p.stockQty <= p.minStock) return C.warning;
    return C.success;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: widget.inCart > 0 ? C.primary : (_hover ? C.primary.withValues(alpha: .45) : C.border),
                  width: widget.inCart > 0 ? 1.5 : 1),
              boxShadow: [
                BoxShadow(
                    color: C.primary.withValues(alpha: _hover ? .12 : .05),
                    blurRadius: _hover ? 18 : 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [C.primary.withValues(alpha: .14), C.secondary.withValues(alpha: .12)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: C.primary, size: 20),
                ),
                const Spacer(),
                if (widget.inCart > 0)
                  BadgeX(text: '\u00d7${widget.inCart}', color: C.primary, icon: Icons.check_rounded),
              ]),
              const Spacer(),
              Text(p.name(gLocale == 'ar'), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Row(children: [
                Text(Money.fmt(p.priceC, locale: gLocale),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.primary)),
                const Spacer(),
                BadgeX(text: '${tr('pos.stock')} ${p.stockQty}', color: _stockColor),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ======================================================== cart panel
class CartPanel extends StatelessWidget {
  const CartPanel({
    super.key,
    required this.lines,
    required this.customerId,
    required this.customers,
    required this.onQty,
    required this.onCustomer,
    required this.onCheckout,
  });

  final List<CartLine> lines;
  final int? customerId;
  final List<Customer> customers;
  final void Function(int productId, int qty) onQty;
  final ValueChanged<int?> onCustomer;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final subtotal = lines.fold<int>(0, (s, l) => s + l.qty * l.product.priceC);
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
        boxShadow: [BoxShadow(color: C.primary.withValues(alpha: .06), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            const Icon(Icons.shopping_cart_rounded, size: 19, color: C.primary),
            const SizedBox(width: 9),
            Text(tr('pos.cart'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            BadgeX(text: '${lines.length}', color: C.primary),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SmartDropdown<int?>(
            items: [null, for (final c in customers) c.id],
            value: customerId,
            display: (id) {
              if (id == null) return tr('pos.walkIn');
              for (final c in customers) {
                if (c.id == id) return c.name(gLocale == 'ar');
              }
              return tr('pos.walkIn');
            },
            onChanged: onCustomer,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: lines.isEmpty
              ? EmptyStateX(title: tr('pos.emptyCart'), body: tr('pos.emptyCartHint'), icon: Icons.shopping_cart_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: lines.length,
                  itemBuilder: (_, i) => _cartRow(context, lines[i]),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFBFE),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Column(children: [
            _summaryRow(tr('subtotal'), subtotal),
            const SizedBox(height: 10),
            AppButton(
              label: '${tr('pos.checkout')} \u2014 ${Money.fmt(subtotal)}',
              icon: Icons.payments_rounded,
              width: double.infinity,
              onPressed: lines.isEmpty ? null : onCheckout,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _cartRow(BuildContext context, CartLine line) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.product.name(gLocale == 'ar'), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            Text('${Money.fmt(line.product.priceC)} \\u00d7 ${line.qty} = ${Money.fmt(line.qty * line.product.priceC)}',
                style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: C.border), borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _qtyBtn(Icons.remove, () => onQty(line.product.id, line.qty - 1)),
            SizedBox(width: 30, child: Text('${line.qty}', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            _qtyBtn(Icons.add, () => onQty(line.product.id, line.qty + 1)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButtonX(icon: Icons.close_rounded, size: 28, onPressed: () => onQty(line.product.id, 0)),
      ]),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 26, height: 26,
          child: Icon(icon, size: 14, color: C.textSecondary),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, int cents) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: C.textSecondary)),
      const Spacer(),
      Text(Money.fmt(cents), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    ]);
  }
}
/// ======================================================== checkout dialog
class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key, required this.lines, required this.customerId, required this.customers});
  final List<CartLine> lines;
  final int? customerId;
  final List<Customer> customers;

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final _discount = TextEditingController(text: '0');
  final _paid = TextEditingController();
  String _method = 'cash';
  bool saving = false;

  Customer? get _customer {
    for (final c in widget.customers) {
      if (c.id == widget.customerId) return c;
    }
    return null;
  }

  int get _subtotalC => widget.lines.fold(0, (s, l) => s + l.qty * l.product.priceC);

  SalesTotals _totals() {
    final prof = context.read<AppState>().profile;
    return computeTotals(
      subtotalC: _subtotalC,
      discountC: Money.fromString(_discount.text),
      taxEnabled: prof.taxEnabled,
      taxRate: prof.taxRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final t = _totals();
    final paidText = (_method == 'credit' || (_paid.text.isEmpty && _method != 'partial'))
        ? (t.totalC / Money.centsPerUnit).toStringAsFixed(2)
        : _paid.text;
    final paidRaw = Money.fromString(paidText);
    final paid = _method == 'credit' ? 0 : paidRaw.clamp(0, t.totalC);
    final due = t.totalC - paid;
    final change = paidRaw > t.totalC ? paidRaw - t.totalC : 0;
    final cust = _customer;
    final needsCustomer = due > 0;

    return PopScope(
      canPop: !saving,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          child: FormHeader(title: tr('checkout.title'), subtitle: tr('checkout.summary')),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFF),
                  border: Border.all(color: C.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  _row(tr('subtotal'), t.subtotalC),
                  FieldX(
                    controller: _discount,
                    label: tr('discount'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    prefix: const Icon(Icons.percent_rounded, size: 17),
                  ),
                  if (st.profile.taxEnabled) ...[
                    _row('${tr('tax')} (${st.profile.taxRate}%)', t.taxC),
                  ],
                  _row(tr('total'), t.totalC),
                ]),
              ),
              const SizedBox(height: 14),
              Text(tr('paymentMethod'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.textSecondary)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                SegmentedX<String>(
                  options: [
                    ('cash', tr('cash')),
                    ('card', tr('card')),
                    ('transfer', tr('transfer')),
                    ('partial', tr('partial')),
                    ('credit', tr('credit')),
                  ],
                  selected: _method,
                  onChanged: (v) => setState(() {
                    _method = v;
                    _paid.text = v == 'credit' ? '0' : (t.totalC / Money.centsPerUnit).toStringAsFixed(2);
                  }),
                ),
              ]),
              if (_method != 'credit') ...[
                const SizedBox(height: 12),
                FieldX(
                  controller: _paid,
                  label: tr('checkout.paidAmount'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  prefix: const Icon(Icons.payments_rounded, size: 17),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final q in const [500, 1000, 2000])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text('$q'),
                        onPressed: () => setState(() {
                          _paid.text = ((paidRaw + q * Money.centsPerUnit)).toString();
                        }),
                      ),
                    ),
                ]),
              ],
              const SizedBox(height: 10),
              _row(tr('paid'), paid),
              if (change > 0) _row(tr('change'), -change),
              if (due > 0) _row(tr('remaining'), due),
              if (needsCustomer && cust == null)
                _hint(tr('partialNeedCustomer'), C.warning)
              else if (needsCustomer && cust != null && cust.creditLimitC > 0 && cust.balanceC + due > cust.creditLimitC)
                _hint(tr('creditExceeded'), C.danger),
            ]),
          ),
        ),
        FormFooter(
          submitLabel: '${tr('checkout.payNow')} \u2014 ${Money.fmt(t.totalC)}',
          enabled: !(due > 0 && cust == null),
          onSubmit: () => _confirm(st, paid: paid, cust: cust),
        ),
      ]),
    );
  }

  Widget _row(String label, int cents) {
    final neg = cents < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13, color: C.textSecondary)),
        const Spacer(),
        Text(Money.fmt(cents), style: TextStyle(
            fontSize: 13.5, fontWeight: label == tr('total') ? FontWeight.w800 : FontWeight.w600,
            color: neg ? C.danger : (label == tr('total') ? C.primary : C.textPrimary))),
      ]),
    );
  }

  Widget _hint(String msg, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: color))),
      ]),
    );
  }

  Future<void> _confirm(AppState st, {required int paid, required Customer? cust}) async {
    final t = _totals();
    final due = t.totalC - paid;
    if (due > 0 && cust == null) return;
    if (due > 0 && cust != null && cust.creditLimitC > 0 && cust.balanceC + due > cust.creditLimitC) {
      Toasts.show(context, tr('creditExceeded'), kind: ToastKind.error);
      return;
    }
    setState(() => saving = true);
    final items = [
      for (final l in widget.lines)
        SaleItem(productId: l.product.id, qty: l.qty, unitPriceC: l.product.priceC, totalC: l.qty * l.product.priceC),
    ];
    try {
      final saleId = await st.sales.createSale(
        customerId: widget.customerId,
        items: items,
        discountC: Money.fromString(_discount.text),
        paymentMethod: _method,
        paidC: paid,
        taxEnabled: st.profile.taxEnabled,
        taxRate: st.profile.taxRate,
      );
      final sale = await st.sales.saleById(saleId);
      final saleItems = await st.sales.saleItems(saleId);
      st.changed();
      if (!mounted) return;
      Navigator.pop(context, saleId);
      if (sale != null) {
        final fmt = st.profile.receiptFormat;
        await PrintService(st).printSale(sale, saleItems, fmt);
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      final msg = e.message;
      if (msg.startsWith('insufficient stock for')) {
        Toasts.show(context, '${tr('checkout.errorStock')} ${msg.split('insufficient stock for')[1].trim()}', kind: ToastKind.error);
      } else {
        Toasts.show(context, msg, kind: ToastKind.error);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      Toasts.show(context, tr('error'), kind: ToastKind.error);
    }
  }
}
