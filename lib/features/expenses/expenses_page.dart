import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';

/// Expenses: add with category/receipt, list, monthly analysis.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});
  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  bool loading = true;
  String? loadError;
  int monthOffset = 0;
  List<Expense> expenses = [];
  List<(String, String, String)> cats = [];
  List<MapEntry<String, int>> monthly = const [];
  int total = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _reload();
  }

  (String, String) get _period {
    final now = DateTime.now();
    final m = DateTime(now.year, now.month - monthOffset);
    final start = DateTime(m.year, m.month);
    final end = DateTime(m.year, m.month + 1);
    return (Dates.iso(start), Dates.iso(end));
  }

  Future<void> _reload() async {
    final st = context.read<AppState>();
    final (from, to) = _period;
    try {
      final res = await Future.wait([
        st.expenses.list(from: from, to: to),
        st.expenses.categories(),
        st.expenses.monthly(12),
        st.expenses.totalC(from, to),
      ]);
      if (!mounted) return;
      setState(() {
        expenses = res[0] as List<Expense>;
        cats = res[1] as List<(String, String, String)>;
        monthly = res[2] as List<MapEntry<String, int>>;
        total = res[3] as int;
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
    final now = DateTime.now();
    final m = DateTime(now.year, now.month - monthOffset);
    final monthLabel = '${m.year}-${m.month.toString().padLeft(2, '0')}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: KpiCard(title: tr('kpi.expenses'), value: Money.fmt(total), icon: 'expense', color: C.warning)),
        Expanded(
          child: HoverCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('chart.expenses'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
              const Spacer(),
              ...[for (final e in monthly.take(6))
                Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
                  Text(e.key, style: const TextStyle(fontSize: 10.5, color: C.textSecondary)),
                  const Spacer(),
                  Text(Money.fmt(e.value), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]))],
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        IconButtonX(icon: Icons.chevron_left_rounded, onPressed: () { setState(() => monthOffset++); _reload(); }),
        Text(monthLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        IconButtonX(icon: Icons.chevron_right_rounded, onPressed: monthOffset == 0 ? null : () { setState(() => monthOffset--); _reload(); }),
        const Spacer(),
        AppButton(label: tr('exp.new'), icon: Icons.receipt_long_rounded, onPressed: () => _add(context)),
      ]),
      const SizedBox(height: 14),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? ErrorStateX(message: loadError!, onRetry: _reload)
                : expenses.isEmpty
                ? EmptyStateX(title: tr('exp.none'), body: tr('exp.noneHint'), icon: Icons.receipt_long_outlined)
                : TableX(
                    columns: [tr('date'), tr('exp.category'), tr('details'), tr('method'), tr('amount'), tr('actions')],
                    widths: [2, 2, 4, 2, 2, 1],
                    rows: [for (final e in expenses) _row(context, e)],
                  ),
      ),
    ]);
  }

  List<Widget> _row(BuildContext context, Expense e) {
    return [
      Text(e.paidAt.substring(0, 10), style: const TextStyle(fontSize: 12)),
      BadgeX(text: _catLabel(e), color: C.secondary),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        if (e.receiptPath != null) Text('📎 ${e.receiptPath!.split('/').last}', style: const TextStyle(fontSize: 10.5, color: C.textSecondary)),
      ]),
      Text(_methodLabel(e.method), style: const TextStyle(fontSize: 12)),
      Text(Money.fmt(e.amountC), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.danger)),
      IconButtonX(icon: Icons.delete_outline, size: 30, color: C.danger, tooltip: tr('delete'), onPressed: () => _remove(context, e)),
    ];
  }

  String _catLabel(Expense e) {
    for (final (k, ar, fr) in cats) {
      if (k == e.categoryKey) return gLocale == 'ar' ? ar : fr;
    }
    return e.categoryKey;
  }

  String _methodLabel(String m) {
    final map = {'cash': tr('cash'), 'card': tr('card'), 'transfer': tr('transfer')};
    return map[m] ?? m;
  }

  Future<void> _remove(BuildContext context, Expense e) async {
    final ok = await confirmDialog(context, title: tr('delete'), body: '${e.description} — ${Money.fmt(e.amountC)}', danger: true);
    if (!ok) return;
    final st = context.read<AppState>();
    await st.expenses.remove(e.id);
    st.changed();
    _reload();
  }

  Future<void> _add(BuildContext context) async {
    final st = context.read<AppState>();
    if (cats.isEmpty) return;
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    String cat = cats.first.$1;
    String method = 'cash';
    String? receipt;
    DateTime date = DateTime.now();
    await formDialog<bool>(context, width: 470, title: tr('exp.new'), body: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Column(children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (k, ar, fr) in cats)
                ChoiceChip(
                  label: Text(gLocale == 'ar' ? ar : fr, style: const TextStyle(fontSize: 11.5)),
                  selected: cat == k,
                  onSelected: (_) => setD(() => cat = k),
                ),
            ]),
            const SizedBox(height: 10),
            FieldX(controller: c1, label: tr('details')),
            const SizedBox(height: 10),
            FieldX(controller: c2, label: tr('amount'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(Dates.isoDay(date)),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (d != null) setD(() => date = d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: Text(receipt == null ? tr('exp.receipt') : receipt!.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onPressed: () async {
                    const tg = XTypeGroup(label: 'Files', extensions: ['pdf', 'png', 'jpg', 'jpeg']);
                    final f = await openFile(acceptedTypeGroups: [tg]);
                    if (f != null) setD(() => receipt = f.path);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 4, children: [
              for (final m in const ['cash', 'card', 'transfer'])
                Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
                  label: Text(_methodLabel(m)),
                  selected: method == m,
                  onSelected: (_) => setD(() => method = m),
                )),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        FormFooter(onSubmit: Money.fromString(c2.text) <= 0 ? () {} : () async {
          final id = await st.expenses.add(
            categoryKey: cat,
            description: c1.text.trim().isEmpty ? (gLocale == 'ar' ? cats.firstWhere((c) => c.$1 == cat).$2 : cats.firstWhere((c) => c.$1 == cat).$3) : c1.text.trim(),
            amountC: Money.fromString(c2.text),
            paidAt: Dates.isoDay(date),
            method: method,
            receiptPath: receipt,
          );
          await st.settings.audit('expense_add', 'expenses', id, '${Money.fromString(c2.text)} $cat');
          if (ctx.mounted) Navigator.pop(ctx, true);
          st.changed();
          _reload();
        }),
      ]),
    ));
  }
}
