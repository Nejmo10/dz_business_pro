import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../printing/print_service.dart';

/// Invoices: sales history, details, printing (A4/80/58 + PDF), returns, cancellations.
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  String query = '';
  String filter = 'all';
  bool loading = true;
  List<Sale> sales = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _reload();
  }

  String? loadError;

  Future<void> _reload() async {
    final st = context.read<AppState>();
    try {
      final list = await st.sales.sales();
      if (!mounted) return;
      setState(() { sales = list; loading = false; loadError = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; loadError = '$e'; });
    }
  }

  List<Sale> get filtered {
    var list = sales;
    if (filter == 'completed') list = list.where((s) => s.status != 'cancelled').toList();
    if (filter == 'cancelled') list = list.where((s) => s.status == 'cancelled').toList();
    if (filter == 'credit') list = list.where((s) => s.totalC > s.paidC).toList();
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      list = list.where((s) => s.invoiceNo.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(flex: 3, child: SearchFieldX(hint: tr('search'), onChanged: (v) => setState(() => query = v))),
        const SizedBox(width: 10),
        SegmentedX<String>(
          options: [('all', tr('all')), ('completed', tr('completed')), ('credit', tr('unpaid')), ('cancelled', tr('cancelled'))],
          selected: filter,
          onChanged: (v) => setState(() => filter = v),
        ),
        const Spacer(),
        Text('${list.length}', style: const TextStyle(fontSize: 13, color: C.textSecondary)),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? ErrorStateX(message: loadError!, onRetry: _reload)
                : list.isEmpty
                ? EmptyStateX(title: tr('inv.none'), body: tr('inv.noneHint'), icon: Icons.receipt_outlined)
                : TableX(
                    columns: [tr('reference'), tr('date'), tr('total'), tr('paid'), tr('remaining'), tr('status'), tr('actions')],
                    widths: [2, 2, 2, 2, 2, 2, 3],
                    rows: [for (final s in list) _row(context, s)],
                  ),
      ),
    ]);
  }

  List<Widget> _row(BuildContext context, Sale s) {
    final cancelled = s.status == 'cancelled';
    return [
      Text(s.invoiceNo, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cancelled ? C.textSecondary : C.primary)),
      Text(s.saleAt.substring(0, 16).replaceAll('T', ' '), style: const TextStyle(fontSize: 12)),
      Text(Money.fmt(s.totalC), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      Text(Money.fmt(s.paidC), style: const TextStyle(fontSize: 12.5, color: C.success)),
      Text(s.totalC > s.paidC ? Money.fmt(s.totalC - s.paidC) : '—',
          style: TextStyle(fontSize: 12.5, color: s.totalC > s.paidC ? C.danger : C.textSecondary)),
      BadgeX(text: cancelled ? tr('cancelled') : (s.totalC > s.paidC ? tr('partial') : tr('paid')), color: cancelled ? C.danger : (s.totalC > s.paidC ? C.warning : C.success)),
      Row(children: [
        IconButtonX(icon: Icons.remove_red_eye_outlined, size: 30, tooltip: tr('details'), onPressed: () => _details(context, s)),
        IconButtonX(icon: Icons.print_outlined, size: 30, tooltip: tr('print'), onPressed: () => _print(context, s)),
        if (!cancelled) IconButtonX(icon: Icons.local_shipping_outlined, size: 30, color: C.success, tooltip: tr('bl.title'), onPressed: () => _deliveryNote(context, s)),
        if (!cancelled) IconButtonX(icon: Icons.assignment_return_outlined, size: 30, color: C.secondary, tooltip: tr('returns'), onPressed: () => _return(context, s)),
      ]),
    ];
  }

  Future<void> _print(BuildContext context, Sale s) async {
    final st = context.read<AppState>();
    final items = await st.sales.saleItems(s.id);
    if (!mounted) return;
    final fmt = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(400, 300, 400, 0),
      items: [
        PopupMenuItem(value: 'a4', child: Text(tr('receipt.a4'))),
        PopupMenuItem(value: '80', child: Text(tr('receipt.80'))),
        PopupMenuItem(value: '58', child: Text(tr('receipt.58'))),
        PopupMenuItem(value: 'pdf', child: Text('PDF')),
      ],
    );
    if (fmt == null || !mounted) return;
    if (fmt == 'pdf') {
      await PrintService(st).exportInvoice(s, items);
    } else {
      await PrintService(st).printSale(s, items, fmt);
    }
  }

  Future<void> _deliveryNote(BuildContext context, Sale s) async {
    final st = context.read<AppState>();
    final items = await st.sales.saleItems(s.id);
    if (!mounted) return;
    final action = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(400, 300, 400, 0),
      items: [
        PopupMenuItem(value: 'print', child: Text(tr('print'))),
        PopupMenuItem(value: 'pdf', child: Text(tr('exportPdf'))),
      ],
    );
    if (action == null || !mounted) return;
    final ps = PrintService(st);
    final bytes = await ps.deliveryNote(s, items);
    if (action == 'pdf') {
      await ps.exportPdf(bytes, 'BL_${s.invoiceNo}.pdf');
    } else {
      await ps.printBytes(bytes);
    }
  }

  Future<void> _details(BuildContext context, Sale s) async {
    final st = context.read<AppState>();
    final items = await st.sales.saleItems(s.id);
    final rets = await st.returns.returns(saleId: s.id);
    final retItems = <Map<String, dynamic>>[];
    for (final r in rets) {
      final rows = await st.database.db.query('return_items', where: 'return_id = ?', whereArgs: [r.id]);
      retItems.addAll(rows.map((m) => m));
    }
    if (!mounted) return;
    await formDialog<void>(context, title: '${tr('inv.details')} — ${s.invoiceNo}', width: 700, body: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.saleAt.substring(0, 16).replaceAll('T', ' '), style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            Text('${tr('method')}: ${_methodLabel(s.paymentMethod)}', style: const TextStyle(fontSize: 12.5)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Money.fmt(s.totalC), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.primary)),
            if (s.discountC > 0) Text('${tr('discount')}: ${Money.fmt(s.discountC)}', style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
            if (s.taxC > 0) Text('${tr('tax')}: ${Money.fmt(s.taxC)}', style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
          ]),
        ]),
        const SizedBox(height: 12),
        for (final it in items) Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(it.nameFr.isNotEmpty ? it.nameFr : it.nameAr, style: const TextStyle(fontSize: 12.5))),
            Text('x${it.qty}', style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            const SizedBox(width: 14),
            Text(Money.fmt(it.unitPriceC), style: const TextStyle(fontSize: 12.5)),
            const Spacer(),
            Text(Money.fmt(it.totalC), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        if (retItems.isNotEmpty) ...[
          const Divider(height: 18),
          Text(tr('returns'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          for (final r in rets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Text(r.returnNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Expanded(child: Text(r.reason, style: const TextStyle(fontSize: 11.5, color: C.textSecondary))),
                Text(Money.fmt(r.totalC), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.danger)),
              ]),
            ),
        ],
        const Divider(height: 18),
        Row(children: [
          Expanded(child: AppButton(label: tr('print'), icon: Icons.print_outlined, onPressed: () { Navigator.pop(ctx); _print(context, s); })),
          const SizedBox(width: 10),
          if (s.status != 'cancelled')
            Expanded(child: AppButton(label: tr('sale.cancel'), icon: Icons.cancel_outlined, kind: AppButtonKind.secondary,
                onPressed: () { Navigator.pop(ctx); _cancel(context, s); })),
        ]),
        const SizedBox(height: 20),
      ]),
    ));
  }

  String _methodLabel(String m) {
    final map = {'cash': tr('cash'), 'card': tr('card'), 'transfer': tr('transfer'), 'partial': tr('partial'), 'credit': tr('credit')};
    return map[m] ?? m;
  }

  Future<void> _cancel(BuildContext context, Sale s) async {
    final ok = await confirmDialog(context, title: '${tr('sale.cancel')} — ${s.invoiceNo}', body: tr('sale.cancelWarn'), danger: true);
    if (!ok) return;
    final st = context.read<AppState>();
    try {
      await st.sales.cancelSale(s.id);
      st.changed();
      _reload();
      if (mounted) Toasts.show(context, tr('success'), kind: ToastKind.success);
    } on AppException catch (e) {
      if (mounted) Toasts.show(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _return(BuildContext context, Sale s) async {
    final st = context.read<AppState>();
    if (s.status == 'cancelled') return;
    final items = await st.sales.saleItems(s.id);
    if (!mounted) return;
    final qty = {for (final it in items) it.id: 0};
    final reason = TextEditingController();
    await formDialog<bool>(context, title: '${tr('returns')} — ${s.invoiceNo}', width: 560, body: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            child: Column(children: [
              for (final it in items) Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(it.nameFr.isNotEmpty ? it.nameFr : it.nameAr, style: const TextStyle(fontSize: 12.5))),
                  Text('${tr('soldQty')}: ${it.qty - it.returnedQty}', style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
                  const SizedBox(width: 10),
                  SizedBox(width: 90, child: TextField(
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(isDense: true, hintText: '0'),
                    onChanged: (v) => setD(() {
                      final avail = it.qty - it.returnedQty;
                      qty[it.id] = (int.tryParse(v) ?? 0).clamp(0, avail);
                    }),
                  )),
                  const SizedBox(width: 6),
                  _stepper(setD, it, qty),
                ]),
              ),
              const SizedBox(height: 10),
              FieldX(controller: reason, label: tr('returns.reason')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        FormFooter(submitLabel: tr('returns'), onSubmit: () async {
          final lines = <(int, int)>[
            for (final it in items)
              if ((qty[it.id] ?? 0) > 0) (it.id, qty[it.id]!),
          ];
          if (lines.isEmpty) {
            Toasts.show(ctx, tr('returns'), kind: ToastKind.warning);
            return;
          }
          try {
            await st.returns.createReturn(saleId: s.id, lines: lines, reason: reason.text.trim());
            if (ctx.mounted) Navigator.pop(ctx, true);
            st.changed();
            _reload();
            if (mounted) Toasts.show(this.context, tr('success'), kind: ToastKind.success);
          } on AppException catch (e) {
            if (mounted) Toasts.show(this.context, e.message, kind: ToastKind.error);
          }
        }),
      ]),
    ));
  }

  Widget _stepper(StateSetter setD, SaleItem it, Map<int, int> qty) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(onTap: () => setD(() { final v = qty[it.id] ?? 0; if (v > 0) qty[it.id] = v - 1; }), child: const Icon(Icons.remove_circle_outline, size: 17, color: C.textSecondary)),
      Text(' ${qty[it.id] ?? 0} ', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      GestureDetector(onTap: () => setD(() { final v = qty[it.id] ?? 0; if (v < it.qty - it.returnedQty) qty[it.id] = v + 1; }), child: const Icon(Icons.add_circle_outline, size: 17, color: C.primary)),
    ]);
  }
}
