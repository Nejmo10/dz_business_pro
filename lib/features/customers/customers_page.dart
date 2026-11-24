import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';

/// Customers CRM: profiles, debts, payments, statements.
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  String query = '';
  bool loading = true;
  String? loadError;
  List<Customer> customers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _reload();
  }

  Future<void> _reload() async {
    final st = context.read<AppState>();
    try {
      final list = await st.people.customers(query: query);
      if (!mounted) return;
      setState(() { customers = list; loading = false; loadError = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; loadError = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDebt = customers.fold<int>(0, (s, c) => s + (c.balanceC > 0 ? c.balanceC : 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(flex: 3, child: SearchFieldX(hint: tr('search'), onChanged: (v) { query = v; _reload(); })),
        const SizedBox(width: 10),
        Text('${tr('kpi.customerDebt')}: ', style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
        Text(Money.fmt(totalDebt), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.danger)),
        const Spacer(),
        AppButton(label: '${tr('customer')} — ${tr('add')}', icon: Icons.person_add_alt_1_rounded, onPressed: () => _edit(context, null)),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? ErrorStateX(message: loadError!, onRetry: _reload)
                : customers.isEmpty
                ? EmptyStateX(title: tr('cust.none'), body: tr('cust.noneHint'), icon: Icons.people_outline,
                    action: AppButton(label: tr('add'), icon: Icons.add, onPressed: () => _edit(context, null)))
                : TableX(
                    columns: [tr('name'), tr('phone'), tr('cust.type'), tr('cust.creditLimit'), tr('cust.balance'), tr('cust.loyalty'), tr('actions')],
                    widths: [3, 2, 1, 2, 2, 2, 2],
                    rows: [for (final c in customers) _row(context, c)],
                  ),
      ),
    ]);
  }

  List<Widget> _row(BuildContext context, Customer c) {
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.name(gLocale == 'ar'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(c.email, style: const TextStyle(fontSize: 11, color: C.textSecondary)),
      ]),
      Text(c.phone, style: const TextStyle(fontSize: 12)),
      Text(c.type == 'wholesale' ? tr('cust.wholesale') : tr('cust.retail'), style: const TextStyle(fontSize: 12)),
      Text(c.creditLimitC == 0 ? '—' : Money.fmt(c.creditLimitC), style: const TextStyle(fontSize: 12)),
      Text(Money.fmt(c.balanceC), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.balanceC > 0 ? C.danger : C.success)),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: BadgeX(
          text: '${_tierLabel(c.loyaltyPoints)} ${c.loyaltyPoints}',
          color: _tierColor(c.loyaltyPoints),
        ),
      ),
      Row(children: [
        IconButtonX(icon: Icons.receipt_long_outlined, size: 30, tooltip: tr('cust.statement'), onPressed: () => _statement(context, c)),
        IconButtonX(icon: Icons.payments_outlined, size: 30, color: C.success, tooltip: tr('payment.addPayment'), onPressed: () => _payment(context, c)),
        IconButtonX(icon: Icons.edit_outlined, size: 30, tooltip: tr('edit'), onPressed: () => _edit(context, c)),
        IconButtonX(icon: Icons.delete_outline, size: 30, color: C.danger, tooltip: tr('delete'), onPressed: () => _delete(context, c)),
      ]),
    ];
  }

  String _tierLabel(int points) {
    if (points >= 500) return tr('tier.gold');
    if (points >= 200) return tr('tier.silver');
    return tr('tier.normal');
  }

  Color _tierColor(int points) {
    if (points >= 500) return const Color(0xFFC9971C);
    if (points >= 200) return const Color(0xFF8892A6);
    return C.textSecondary;
  }

  Future<void> _delete(BuildContext context, Customer c) async {
    final ok = await confirmDialog(context, title: '${tr('delete')} — ${c.name(gLocale == 'ar')}', body: tr('cust.deleteWarn'), danger: true);
    if (!ok) return;
    final st = context.read<AppState>();
    await st.people.deleteCustomer(c.id);
    st.changed();
    _reload();
  }

  Future<void> _edit(BuildContext context, Customer? existing) async {
    final st = context.read<AppState>();
    final c1 = TextEditingController(text: existing?.nameAr ?? '');
    final c2 = TextEditingController(text: existing?.nameFr ?? '');
    final c3 = TextEditingController(text: existing?.phone ?? '');
    final c4 = TextEditingController(text: existing?.email ?? '');
    final c5 = TextEditingController(text: existing?.address ?? '');
    final c6 = TextEditingController(text: existing?.notes ?? '');
    final c7 = TextEditingController(text: (existing?.creditLimitC ?? 0) / Money.centsPerUnit == 0 ? '' : ((existing!.creditLimitC) / Money.centsPerUnit).toStringAsFixed(2));
    String type = existing?.type ?? 'retail';
    await formDialog<bool>(context, width: 560, title: existing == null ? tr('cust.new') : tr('cust.edit') , body: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => Column(mainAxisSize: MainAxisSize.min, children: [
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
              Expanded(child: FieldX(controller: c3, label: tr('phone'), keyboardType: TextInputType.phone)),
              const SizedBox(width: 10),
              Expanded(child: FieldX(controller: c4, label: 'Email', keyboardType: TextInputType.emailAddress)),
            ]),
            const SizedBox(height: 10),
            FieldX(controller: c5, label: tr('address')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: SegmentedX<String>(options: [('retail', tr('cust.retail')), ('wholesale', tr('cust.wholesale'))], selected: type, onChanged: (v) => setD(() => type = v))),
              const SizedBox(width: 14),
              Expanded(child: FieldX(controller: c7, label: tr('cust.creditLimit'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            const SizedBox(height: 10),
            FieldX(controller: c6, label: tr('notes'), maxLines: 2),
          ]),
        ),
        const SizedBox(height: 16),
        FormFooter(onSubmit: () async {
          if (c1.text.trim().isEmpty && c2.text.trim().isEmpty) {
            Toasts.show(ctx, tr('requiredField'), kind: ToastKind.warning);
            return;
          }
          final cust = Customer(
            id: existing?.id ?? 0,
            nameAr: c1.text.trim(), nameFr: c2.text.trim(),
            phone: c3.text.trim(), email: c4.text.trim(),
            address: c5.text.trim(), notes: c6.text.trim(), type: type,
            creditLimitC: Money.fromString(c7.text),
            balanceC: existing?.balanceC ?? 0,
          );
          await st.people.saveCustomer(cust);
          await st.settings.audit(existing == null ? 'customer_create' : 'customer_update', 'customers', cust.id, cust.nameFr);
          if (ctx.mounted) Navigator.pop(ctx, true);
          _reload();
        }),
      ]),
    ));
    _reload();
  }

  Future<void> _payment(BuildContext context, Customer c) async {
    final st = context.read<AppState>();
    final c1 = TextEditingController();
    String method = 'cash';
    await formDialog<bool>(context, width: 420, title: tr('payment.addPayment'), body: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Column(children: [
            _simpleRow(tr('cust.balance'), Money.fmt(c.balanceC)),
            _simpleRow(tr('customer'), c.name(gLocale == 'ar')),
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
          await st.people.recordPayment(direction: 'sale', refId: 0, partyId: c.id,
              amountC: Money.fromString(c1.text), method: method, notes: tr('payment.receiptOf'));
          await st.settings.audit('customer_payment', 'customers', c.id, c.nameFr);
          if (ctx.mounted) Toasts.show(this.context, tr('payment.recorded'), kind: ToastKind.success);
          if (ctx.mounted) Navigator.pop(ctx, true);
          st.changed();
          _reload();
        }),
      ]),
    ));
  }

  Future<void> _statement(BuildContext context, Customer c) async {
    final st = context.read<AppState>();
    final sales = await st.people.customerSales(c.id);
    final pays = await st.people.payments(direction: 'sale', partyId: c.id);
    final fresh = await st.people.customerById(c.id);
    if (!mounted) return;
    final balance = fresh?.balanceC ?? c.balanceC;
    await formDialog<void>(context, title: tr('cust.statement'), width: 700, body: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name(gLocale == 'ar'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              Text('${c.phone}  ·  ${c.type == 'wholesale' ? tr('cust.wholesale') : tr('cust.retail')}', style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(tr('cust.balance'), style: const TextStyle(fontSize: 11, color: C.textSecondary)),
              Text(Money.fmt(balance), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: balance > 0 ? C.danger : C.success)),
              const SizedBox(height: 4),
              BadgeX(text: '${tr('cust.loyalty')}: ${c.loyaltyPoints}', color: _tierColor(c.loyaltyPoints)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Text(tr('cust.purchases'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        for (final s in sales)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Text('${s['invoice_no']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Text((s['sale_at'] as String).substring(0, 10), style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
              const Spacer(),
              Text(Money.fmt(s['total_c'] as int), style: const TextStyle(fontSize: 12.5)),
              const SizedBox(width: 14),
              Text(Money.fmt(s['paid_c'] as int), style: const TextStyle(fontSize: 12.5, color: C.success)),
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
