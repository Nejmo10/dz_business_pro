import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

/// Inventory: valuation, alerts, manual moves, counting, full history.
class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  bool loading = true;
  int stockValue = 0, units = 0, lowCount = 0, productCount = 0, outCount = 0;
  List<Product> lowProducts = [];
  List<StockMovement> movements = [];

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
      st.inventory.stockValueC(),
      st.inventory.stockUnits(),
      st.inventory.lowStockCount(),
      st.inventory.productCount(),
      st.catalog.products(onlyLowStock: true, includeArchived: true),
      st.inventory.movements(limit: 150),
      st.inventory.outCount(),
    ]);
    if (!mounted) return;
    setState(() {
      stockValue = res[0] as int;
      units = res[1] as int;
      lowCount = res[2] as int;
      productCount = res[3] as int;
      lowProducts = res[4] as List<Product>;
      movements = res[5] as List<StockMovement>;
      outCount = res[6] as int;
      loading = false;
      loadError = null;
    });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; loadError = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: KpiCard(title: tr('inv.value'), value: Money.fmt(stockValue), icon: 'products', color: C.primary)),
        const SizedBox(width: 12),
        Expanded(child: KpiCard(title: tr('inv.units'), value: '$units', icon: 'products', color: C.secondary)),
        const SizedBox(width: 12),
        Expanded(child: KpiCard(title: tr('kpi.lowStock'), value: '$lowCount', icon: 'lowstock', color: C.warning)),
        const SizedBox(width: 12),
        Expanded(child: KpiCard(title: tr('inv.outOfStock'), value: '$outCount', icon: 'lowstock', color: C.danger)),
        const SizedBox(width: 12),
        Expanded(child: KpiCard(title: tr('kpi.products'), value: '$productCount', icon: 'products', color: C.accent)),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        AppButton(label: tr('inv.stockIn'), icon: Icons.south_west_rounded, onPressed: () => _move(context, 'in')),
        const SizedBox(width: 8),
        AppButton(label: tr('inv.stockOut'), icon: Icons.north_east_rounded, kind: AppButtonKind.secondary, onPressed: () => _move(context, 'out')),
        const SizedBox(width: 8),
        AppButton(label: tr('inv.counting'), icon: Icons.fact_check_outlined, kind: AppButtonKind.ghost, onPressed: () => _counting(context)),
        const SizedBox(width: 8),
        AppButton(label: tr('inv.allowNegative'), kind: AppButtonKind.ghost, onPressed: () => _toggleNegative(st)),
      ]),
      const SizedBox(height: 14),
      if (lowCount > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.warning.withValues(alpha: .08),
              border: Border.all(color: C.warning.withValues(alpha: .45)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${tr('inv.alertLow')}: ${lowProducts.take(6).map((p) => p.name(gLocale == 'ar')).join(' · ')}${lowProducts.length > 6 ? '…' : ''}',
              style: const TextStyle(fontSize: 12.5, color: C.warning, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? ErrorStateX(message: loadError!, onRetry: _reload)
            : movements.isEmpty
                ? EmptyStateX(title: tr('inv.movements'), body: tr('inv.emptyHint'), icon: Icons.swap_vert_rounded)
                : TableX(
                    columns: [tr('date'), tr('nav.commerce'), tr('product.type'), tr('quantity'), tr('inv.balance'), tr('notes')],
                    widths: [2, 3, 1, 1, 1, 2],
                    rows: [for (final m in movements) _movementRow(m)],
                  ),
      ),
    ]);
  }

  List<Widget> _movementRow(StockMovement m) {
    final inType = m.type == 'in';
    return [
      Text(Dates.parse(m.movedAt).toString().substring(0, 16), style: const TextStyle(fontSize: 12)),
      Text(m.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      BadgeX(text: m.type, color: inType ? C.success : (m.type == 'out' ? C.danger : C.secondary)),
      Text('${inType ? '+' : '-'}${m.qty}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: inType ? C.success : C.danger)),
      Text('${m.balanceAfter}', style: const TextStyle(fontSize: 12.5)),
      Text(m.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.textSecondary)),
    ];
  }

  Future<void> _toggleNegative(AppState st) async {
    final ok = await confirmDialog(context, title: tr('inv.allowNegative'), body: tr('inv.allowNegativeWarn'));
    if (!ok) return;
    final v = !(await st.settings.allowNegativeStock());
    await st.settings.setAllowNegativeStock(v);
    await st.settings.audit('settings_negative_$v', 'app_settings', null, '');
    st.changed();
  }

  Future<void> _move(BuildContext context, String type) async {
    final st = context.read<AppState>();
    final prods = await st.catalog.products(includeArchived: true);
    if (!mounted) return;
    int? pid; int qty = 1;
    final c1 = TextEditingController();
    await formDialog<void>(context, width: 440, title: type == 'in' ? tr('inv.stockIn') : tr('inv.stockOut'), body: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Column(children: [
            SmartDropdown<int>(items: [for (final p in prods) p.id], value: pid,
                display: (id) => prods.firstWhere((p) => p.id == id).name(gLocale == 'ar'),
                onChanged: (v) => setD(() => pid = v), label: tr('product.details')),
            const SizedBox(height: 10),
            FieldX(controller: c1, label: tr('quantity'), keyboardType: TextInputType.number,
                onChanged: (v) => setD(() => qty = int.tryParse(v) ?? 1)),
          ]),
        ),
        const SizedBox(height: 16),
        FormFooter(submitLabel: tr('confirm'), onSubmit: () async {
          if (pid == null || qty <= 0) {
            Toasts.show(ctx, tr('requiredField'), kind: ToastKind.warning);
            return;
          }
          final st = context.read<AppState>();
          try {
            await st.inventory.applyManualMove(productId: pid!, type: type, qty: qty,
                note: type == 'in' ? 'manual in' : 'manual out');
            if (ctx.mounted) Navigator.pop(ctx);
            st.changed();
            _reload();
          } on AppException catch (e) {
            Toasts.show(this.context, e.message, kind: ToastKind.error);
          }
        }),
      ]),
    ));
  }

  Future<void> _counting(BuildContext context) async {
    final st = context.read<AppState>();
    final prods = await st.catalog.products();
    if (!mounted) return;
    final map = {for (final p in prods) p.id: p.stockQty};
    await formDialog<void>(context, title: tr('inv.counting'), body: (ctx) => SizedBox(
      width: 480,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 340,
          child: ListView(children: [
            for (final p in prods) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
              child: Row(children: [
                Expanded(child: Text(p.name(gLocale == 'ar'), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5))),
                Text('→ ${map[p.id]}', style: const TextStyle(fontSize: 12, color: C.textSecondary)),
                const SizedBox(width: 10),
                SizedBox(width: 90, child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(isDense: true, hintText: '${p.stockQty}'),
                  textAlign: TextAlign.center,
                  onChanged: (v) { final q = int.tryParse(v); if (q != null) map[p.id] = q; },
                )),
              ]),
            ),
          ]),
        ),
        FormFooter(submitLabel: tr('inv.applyCounting'), onSubmit: () async {
          final st = context.read<AppState>();
          for (final p in prods) {
            final target = map[p.id];
            if (target == null || target == p.stockQty) continue;
            try {
              await st.inventory.applyManualMove(
                  productId: p.id, type: target > p.stockQty ? 'in' : 'out',
                  qty: (target - p.stockQty).abs(), note: 'stock counting');
            } on AppException {
              continue;
            }
          }
          if (ctx.mounted) Navigator.pop(ctx);
          st.changed();
          _reload();
        }),
      ]),
    ));
  }
}
