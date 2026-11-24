import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';

/// Suppliers: profiles, payables, payments, statements.
class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});
  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  String query = '';
  bool loading = true;
  List<Supplier> suppliers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _reload();
  }

  Future<void> _reload() async {
    final st = context.read<AppState>();
    final list = await st.people.suppliers(query: query);
    if (!mounted) return;
    setState(() { suppliers = list; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final totalDebt = suppliers.fold<int>(0, (s, c) => s + (c.balanceC > 0 ? c.balanceC : 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(flex: 3, child: SearchFieldX(hint: tr('search'), onChanged: (v) { query = v; _reload(); })),
        const SizedBox(width: 10),
        Text('${tr('kpi.supplierDebt')}: ', style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
        Text(Money.fmt(totalDebt), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.danger)),
        const Spacer(),
        AppButton(label: tr('add'), icon: Icons.local_shipping_rounded, onPressed: () => _edit(context, null)),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : suppliers.isEmpty
                ? EmptyStateX(title: tr('sup.none'), body: tr('sup.noneHint'), icon: Icons.local_shipping_outlined,
                    action: AppButton(label: tr('add'), icon: Icons.add, onPressed: () => _edit(context, null)))
                : TableX(
                    columns: [tr('name'), tr('company'), tr('phone'), tr('cust.balance'), tr('actions')],
                    widths: [3, 2, 2, 2, 2],
                    rows: [for (final s in suppliers) _row(context, s)],
                  ),
      ),
    ]);
  }

  List<Widget> _row(BuildContext context, Supplier s) {
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.name(gLocale == 'ar'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(s.email, style: const TextStyle(fontSize: 11, color: C.textSecondary)),
      ]),
      Text(s.company, style: const TextStyle(fontSize: 12)),
      Text(s.contact.isEmpty ? s.phone : s.contact, style: const TextStyle(fontSize: 12)),
      Text(Money.fmt(s.balanceC), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: s.balanceC > 0 ? C.danger : C.success)),
      Row(children: [
        IconButtonX(icon: Icons.receipt_long_outlined, size: 30, tooltip: tr('sup.statement'), onPressed: () => _statement(context, s)),
        IconButtonX(icon: Icons.payments_outlined, size: 30, color: C.success, tooltip: tr('payment.paidTo'), onPressed: () => _payment(context, s)),
        IconButtonX(icon: Icons.edit_outlined, size: 30, tooltip: tr('edit'), onPressed: () => _edit(context, s)),
        IconButtonX(icon: Icons.delete_outline, size: 30, color: C.danger, tooltip: tr('delete'), onPressed: () => _delete(context, s)),
      ]),
    ];
  }

  Future<void> _delete(BuildContext context, Supplier s) async {
    final ok = await confirmDialog(context, title: '${tr('delete')} — ${s.name(gLocale == 'ar')}', body: tr('sup.deleteWarn'), danger: true);
    if (!ok) return;
    final st = context.read<AppState>();
    await st.people.deleteSupplier(s.id);
    st.changed();
    _reload();
  }

  Future<void> _edit(BuildContext context, Supplier? existing) async {
    final st = context.read<AppState>();
    final c1 = TextEditingController(text: existing?.nameAr ?? '');
    final c2 = TextEditingController(text: existing?.nameFr ?? '');
    final c3 = TextEditingController(text: existing?.company ?? '');
    final c4 = TextEditingController(text: existing?.contact ?? '');
    final c5 = TextEditingController(text: existing?.phone ?? '');
    final c6 = TextEditingController(text: existing?.email ?? '');
    final c7 = TextEditingController(text: existing?.address ?? '');
    final c8 = TextEditingController(text: existing?.notes ?? '');
    await formDialog<bool>(context, width: 580, title: existing == null ? tr('sup.new') : tr('sup.edit'), body: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        child: Column(children: [
          Row(children: [
            Expanded(child: FieldX(controller: c2, label: '${tr('name')} (FR)')),
            const SizedBox(width: 10),
            Expanded(child: FieldX(controller: c1, label: '${tr('name')} (AR)')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FieldX(controller: c3, label: tr('company'))),
            const SizedBox(width: 10),
            Expanded(child: FieldX(controller: c4, label: tr('contact'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FieldX(controller: c5, label: tr('phone'), keyboardType: TextInputType.phone)),
            const SizedBox(width: 10),
            Expanded(child: FieldX(controller: c6, label: tr('email'), keyboardType: TextInputType.emailAddress)),
          ]),
          const SizedBox(height: 10),
          FieldX(controller: c7, label: tr('address')),
          const SizedBox(height: 10),
          FieldX(controller: c8, label: tr('notes'), maxLines: 2),
        ]),
      ),
      const SizedBox(height: 16),
      FormFooter(onSubmit: (c1.text.trim().isEmpty && c2.text.trim().isEmpty) ? () {} : () async {
        final sup = Supplier(
          id: existing?.id ?? 0,
          nameAr: c1.text.trim(), nameFr: c2.text.trim(),
          company: c3.text.trim(), contact: c4.text.trim(),
          phone: c5.text.trim(), email: c6.text.trim(),
          address: c7.text.trim(), notes: c8.text.trim(),
          balanceC: existing?.balanceC ?? 0,
        );
        await st.people.saveSupplier(sup);
        await st.settings.audit(existing == null ? 'supplier_create' : 'supplier_update', 'suppliers', sup.id, sup.nameFr);
        if (ctx.mounted) Navigator.pop(ctx, true);
        _reload();
      }),
    ]));
    _reload();
  }

  Future<void> _payment(BuildContext context, Supplier s) async {
    final st = context.read<AppState>();
    final c1 = TextEditingController();
    String method = 'cash';
    await formDialog<bool>(context, width: 420, title: tr('payment.paidTo'), body: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Column(children: [
            _simpleRow(tr('cust.balance'), Money.fmt(s.balanceC)),
            _simpleRow(tr('supplier'), s.name(gLocale == 'ar')),
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
        FormFooter(onSubmit: Money.fromString(c1.text) <= 0 ? () {} : () async {
          await st.people.recordPayment(direction: 'purchase', refId: 0, partyId: s.id,
              amountC: Money.fromString(c1.text), method: method, notes: tr('payment.paidTo'));
          await st.settings.audit('supplier_payment', 'suppliers', s.id, s.nameFr);
          if (ctx.mounted) Navigator.pop(ctx, true);
          st.changed();
          _reload();
        }),
      ]),
    ));
  }

  Future<void> _statement(BuildContext context, Supplier s) async {
    final st = context.read<AppState>();
    final purchases = await st.people.supplierPurchases(s.id);
    final pays = await st.people.payments(direction: 'purchase', partyId: s.id);
    final fresh = await st.people.supplierById(s.id);
    if (!mounted) return;
    final balance = fresh?.balanceC ?? s.balanceC;
    await formDialog<void>(context, title: tr('sup.statement'), width: 700, body: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name(gLocale == 'ar'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              Text(s.company.isEmpty ? s.phone : s.company, style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(tr('cust.balance'), style: const TextStyle(fontSize: 11, color: C.textSecondary)),
              Text(Money.fmt(balance), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: balance > 0 ? C.danger : C.success)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Text(tr('purchases'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        for (final pu in purchases)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Text('${pu['invoice_no']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Text((pu['purchase_at'] as String).substring(0, 10), style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
              const Spacer(),
              Text(Money.fmt(pu['total_c'] as int), style: const TextStyle(fontSize: 12.5)),
              const SizedBox(width: 14),
              Text(Money.fmt(pu['paid_c'] as int), style: const TextStyle(fontSize: 12.5, color: C.success)),
            ]),
          ),
        const SizedBox(height: 12),
        Text(tr('payment.history'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        if (pays.isEmpty) Text(tr('noPayments'), style: const TextStyle(fontSize: 12, color: C.textSecondary))
        else for (final pay in pays)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Text(pay.paidAt.substring(0, 10), style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
              const SizedBox(width: 10),
              Expanded(child: Text(pay.notes, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
              Text(pay.kind == 'refund' ? '-${Money.fmt(pay.amountC)}' : Money.fmt(pay.amountC),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: pay.kind == 'refund' ? C.danger : C.success)),
            ]),
          ),
        const SizedBox(height: 20),
      ]),
    ));
  }

  Widget _simpleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: C.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
