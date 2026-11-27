import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

/// Financial management: cash register sessions, cash movements, profit
/// summary and receivables/payables. All values come from real records.
class FinancePage extends StatefulWidget {
  const FinancePage({super.key});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  bool loading = true;
  CashRegister? open;
  List<CashRegister> history = [];
  List<CashMovement> moves = [];
  int revenueC = 0, salesN = 0, grossC = 0, netC = 0, expensesC = 0;
  int receivableC = 0, payableC = 0;
  int paymentsInC = 0, paymentsOutC = 0;
  int expectedC = 0;
  int monthOffset = 0;
  CashRegister? openBank, openRes;
  int expectedBank = 0, expectedRes = 0;
  List<CheckRec> checks = [];
  List<AdvanceRec> advances = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _reload();
  }

  List<(String, String)> get _monthRange {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month - monthOffset, 1);
    final last = DateTime(first.year, first.month + 1, 1).subtract(const Duration(seconds: 1));
    final f = first.toIso8601String().substring(0, 10);
    final t = last.toIso8601String().substring(0, 19);
    return [(f, t)];
  }

  String? loadError;

  Future<void> _reload() async {
    final st = context.read<AppState>();
    try {
    final (from, to) = _monthRange.first;
    final reg = await st.cash.openRegister();
    final expected = reg == null ? 0 : await st.cash.expectedCash(reg.id);
    final results = await Future.wait([
      st.analytics.salesSum(from, to),
      st.analytics.salesCount(from, to),
      st.analytics.grossProfitC(from, to),
      st.analytics.expensesC(from, to),
      st.database.db.rawQuery('SELECT COALESCE(SUM(MAX(balance_c - credit_limit_c, 0)),0) AS v FROM customers'),
      st.database.db.rawQuery(
          'SELECT COALESCE(SUM(MAX(total_c - paid_c, 0)),0) AS v FROM purchases WHERE status != \'cancelled\''),
      st.database.db.rawQuery(
          "SELECT COALESCE(SUM(amount_c),0) AS v FROM payments WHERE kind='payment' AND direction='sale' AND paid_at >= ? AND paid_at <= ?",
          [from, to]),
      st.database.db.rawQuery(
          "SELECT COALESCE(SUM(amount_c),0) AS v FROM payments WHERE direction='purchase' AND paid_at >= ? AND paid_at <= ?",
          [from, to]),
      st.cash.registers(),
      st.cash.movements(),
    ]);
    final openBank0 = await st.cash.openRegister(kind: 'bank');
    final openRes0 = await st.cash.openRegister(kind: 'reserve');
    final expBank = openBank0 == null ? 0 : await st.cash.expectedCash(openBank0.id);
    final expRes = openRes0 == null ? 0 : await st.cash.expectedCash(openRes0.id);
    final checksList = await st.checks.list(limit: 15);
    final advList = await st.advances.list(limit: 50);
    if (!mounted) return;
    receivableC = ((results[4] as List<Map<String, Object?>>).first['v'] as int?) ?? 0;
    payableC = ((results[5] as List<Map<String, Object?>>).first['v'] as int?) ?? 0;
    paymentsInC = ((results[6] as List<Map<String, Object?>>).first['v'] as int?) ?? 0;
    paymentsOutC = ((results[7] as List<Map<String, Object?>>).first['v'] as int?) ?? 0;
    setState(() {
      open = reg;
      expectedC = expected;
      revenueC = results[0] as int;
      salesN = results[1] as int;
      grossC = results[2] as int;
      expensesC = results[3] as int;
      netC = grossC - expensesC;
      history = results[8] as List<CashRegister>;
      moves = results[9] as List<CashMovement>;
      openBank = openBank0;
      openRes = openRes0;
      expectedBank = expBank;
      expectedRes = expRes;
      checks = checksList;
      advances = advList;
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
    if (loading) return const Center(child: CircularProgressIndicator());
    if (loadError != null) return ErrorStateX(message: loadError!, onRetry: _reload);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _registerSection(context),
        const SizedBox(height: 16),
        _vaultsSection(context),
        const SizedBox(height: 16),
        _summarySection(context),
        const SizedBox(height: 16),
        _balancesSection(context),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _historyCard(context)),
          const SizedBox(width: 14),
          Expanded(child: _paymentsCard()),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _checksSection(context)),
          const SizedBox(width: 14),
          Expanded(child: _advancesSection(context)),
        ]),
      ]),
    );
  }

  // -------------------------------------------------------------- register --
  Widget _registerSection(BuildContext context) {
    final st = context.read<AppState>();
    if (open == null) return _registerClosedCard(context, st);
    return Row(children: [
      _sessionTile(tr('cash.opening'), Money.fmt(open!.openingC), Icons.lock_open_rounded, C.primary),
      const SizedBox(width: 12),
      _sessionTile(tr('cash.expected'), Money.fmt(expectedC), Icons.account_balance_wallet_outlined, C.accent),
      const SizedBox(width: 12),
      _actionTile(tr('cash.in'), tr('cash.inHint'), Icons.south_west_rounded, C.success,
          () => _cashMove(context, st, cashIn: true)),
      const SizedBox(width: 12),
      _actionTile(tr('cash.out'), tr('cash.outHint'), Icons.north_east_rounded, C.danger,
          () => _cashMove(context, st, cashIn: false)),
      const SizedBox(width: 12),
      _actionTile(tr('cash.close'), tr('cash.closeHint'), Icons.lock_rounded, C.primary,
          () => _closeRegister(context, st)),
    ]);
  }

  Widget _sessionTile(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }

  Widget _actionTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: C.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.border),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: C.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _registerClosedCard(BuildContext context, AppState st) {
    final ctrl = TextEditingController(text: '0');
    return HoverCard(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.account_balance_wallet_outlined, color: C.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('cash.closedTitle'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(tr('cash.closedHint'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
        ])),
        const SizedBox(width: 14),
        SizedBox(
          width: 160,
          child: FieldX(controller: ctrl, label: tr('amount'), keyboardType: TextInputType.number),
        ),
        const SizedBox(width: 10),
        AppButton(
          label: tr('cash.open'),
          icon: Icons.play_arrow_rounded,
          onPressed: () async {
            final amount = Money.fromString(ctrl.text);
            try {
              await st.cash.open(amount);
              await st.settings.audit('cash_open', 'cash_registers', 0, Money.fmt(amount));
              st.changed();
              _reload();
              if (mounted) Toasts.show(context, tr('success'), kind: ToastKind.success);
            } on AppException catch (e) {
              if (mounted) Toasts.show(context, e.message, kind: ToastKind.error);
            }
          },
        ),
      ]),
    );
  }

  Future<void> _closeRegister(BuildContext context, AppState st) async {
    final expected = await st.cash.expectedCash(open!.id);
    if (!mounted) return;
    final counted = TextEditingController(text: Money.fmt(expected));
    final ok = await formDialog<bool>(context,
      title: tr('cash.close'),
      width: 440,
      body: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tr('cash.expected'), style: const TextStyle(fontSize: 13, color: C.textSecondary)),
            Text(Money.fmt(expected), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.primary)),
          ]),
          const SizedBox(height: 14),
          FieldX(controller: counted, label: tr('cash.counted'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
        ]),
      ),
    );
    if (ok != true) return;
    try {
      await st.cash.closeRegister(open!.id, Money.fromString(counted.text));
      await st.settings.audit('cash_close', 'cash_registers', open!.id, Money.fmt(Money.fromString(counted.text)));
      st.changed();
      _reload();
      if (mounted) Toasts.show(context, tr('success'), kind: ToastKind.success);
    } on AppException catch (e) {
      if (mounted) Toasts.show(context, e.message, kind: ToastKind.error);
    }
  }

  // ---------------------------------------------------------------- summary --
  Widget _summarySection(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tr('fin.summary'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          SegmentedX<String>(
            options: [for (int i = 0; i < 3; i++) ('$i', _monthName(i))],
            selected: '$monthOffset',
            onChanged: (v) { setState(() => monthOffset = int.parse(v)); _reload(); },
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: KpiCard(title: tr('kpi.revenue'), value: Money.fmt(revenueC), icon: 'revenue', color: C.primary, subtitle: '${tr('salesCount2')}: $salesN')),
          const SizedBox(width: 12),
          if (context.read<AppState>().canSeeProfits) ...[
            Expanded(child: KpiCard(title: tr('kpi.grossProfit'), value: Money.fmt(grossC), icon: 'profit', color: C.accent, subtitle: tr('fin.grossHint'))),
            const SizedBox(width: 12),
          ],
          Expanded(child: KpiCard(title: tr('kpi.expenses'), value: Money.fmt(expensesC), icon: 'expense', color: C.warning, subtitle: _monthName(monthOffset))),
          const SizedBox(width: 12),
          if (context.read<AppState>().canSeeProfits)
            Expanded(child: KpiCard(title: tr('kpi.netProfit'), value: Money.fmt(netC), icon: 'net', color: netC >= 0 ? C.success : C.danger, subtitle: tr('fin.netHint'))),
        ]),
      ]),
    );
  }

  String _monthName(int offset) {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month - offset, 1);
    return gIsArabic
        ? '${d.year}/${d.month.toString().padLeft(2, '0')}'
        : '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  // --------------------------------------------------------------- balances --
  Widget _balancesSection(BuildContext context) {
    return Row(children: [
      Expanded(child: _balanceCard(
        tr('fin.receivables'), Money.fmt(receivableC), Icons.person_search_outlined, C.warning,
        tr('fin.receivablesHint'),
      )),
      const SizedBox(width: 14),
      Expanded(child: _balanceCard(
        tr('fin.payables'), Money.fmt(payableC), Icons.local_shipping_outlined, C.danger,
        tr('fin.payablesHint'),
      )),
    ]);
  }

  Widget _balanceCard(String title, String value, IconData icon, Color color, String hint) {
    return HoverCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: C.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(hint, style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
        ])),
      ]),
    );
  }

  // ----------------------------------------------------------------- vaults --
  Widget _vaultsSection(BuildContext context) {
    final st = context.read<AppState>();
    final openCount = [open, openBank, openRes].where((r) => r != null).length;
    return HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_rounded, size: 17, color: C.secondary),
          const SizedBox(width: 8),
          Text(tr('fin.registers'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          AppButton(
            label: tr('fin.transfer'), icon: Icons.swap_horiz_rounded,
            kind: AppButtonKind.secondary,
            onPressed: openCount >= 2 ? () => _transfer(context, st) : null,
          ),
          const SizedBox(width: 10),
          AppButton(
            label: tr('fin.openRegister'), icon: Icons.add_business_rounded,
            kind: AppButtonKind.ghost,
            onPressed: () => _openVault(context, st),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _vaultTile(context, 'cash', tr('fin.cashVault'), open, expectedC, Icons.local_atm_rounded, C.primary, st)),
          const SizedBox(width: 12),
          Expanded(child: _vaultTile(context, 'bank', tr('fin.bankVault'), openBank, expectedBank, Icons.account_balance_rounded, C.secondary, st)),
          const SizedBox(width: 12),
          Expanded(child: _vaultTile(context, 'reserve', tr('fin.reserveVault'), openRes, expectedRes, Icons.savings_outlined, C.accent, st)),
        ]),
      ]),
    );
  }

  Widget _vaultTile(BuildContext context, String kind, String label, CashRegister? reg, int expected, IconData icon, Color color, AppState st) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(reg == null
                  ? '-'
                  : (reg.name.isNotEmpty ? reg.name : reg.openedAt.substring(0, 10)),
              style: const TextStyle(fontSize: 11, color: C.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 8),
        if (reg == null)
          IconButtonX(icon: Icons.play_arrow_rounded, size: 30, color: C.success,
              tooltip: tr('cash.open'), onPressed: () => _openVault(context, st, presetKind: kind))
        else
          Text(Money.fmt(expected, locale: gLocale), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.primary)),
      ]),
    );
  }

  Future<void> _openVault(BuildContext context, AppState st, {String? presetKind}) async {
    final name = TextEditingController();
    final amount = TextEditingController(text: '0');
    String kind = presetKind ?? 'bank';
    final ok = await formDialog<bool>(context,
      title: tr('fin.openRegister'),
      width: 440,
      body: (ctx) => StatefulBuilder(builder: (ctx, setD) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedX<String>(
            options: [('cash', tr('fin.cashVault')), ('bank', tr('fin.bankVault')), ('reserve', tr('fin.reserveVault'))],
            selected: kind,
            onChanged: presetKind == null
                ? (v) => setD(() => kind = v)
                : (v) => setD(() {}),
          ),
          const SizedBox(height: 14),
          FieldX(controller: name, label: tr('fin.registerName')),
          const SizedBox(height: 12),
          FieldX(controller: amount, label: tr('amount'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
        ]),
      )),
    );
    if (ok != true) return;
    try {
      final id = await st.cash.open(Money.fromString(amount.text), kind: kind, name: name.text.trim());
      await st.settings.audit('cash_open', 'cash_registers', id, kind);
      st.changed();
      _reload();
      if (context.mounted) Toasts.show(context, tr('success'), kind: ToastKind.success);
    } on AppException catch (e) {
      if (context.mounted) Toasts.show(context, e.message, kind: ToastKind.error);
    }
  }

  Future<void> _transfer(BuildContext context, AppState st) async {
    final regs = [if (open != null) open!, if (openBank != null) openBank!, if (openRes != null) openRes!];
    if (regs.length < 2) return;
    int from = regs.first.id, to = regs[1].id;
    final amount = TextEditingController();
    final reason = TextEditingController();
    String label(CashRegister r) {
      final kindLabel = tr('fin.${r.kind}Vault');
      return r.name.isEmpty ? kindLabel : r.name;
    }
    final ok = await formDialog<bool>(context,
      title: tr('fin.transfer'),
      width: 440,
      body: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SmartDropdown<int>(
            items: [for (final r in regs) r.id],
            value: from,
            display: (id) => label(regs.firstWhere((r) => r.id == id)),
            onChanged: (v) => from = v ?? from,
            label: tr('from'),
          ),
          const SizedBox(height: 12),
          SmartDropdown<int>(
            items: [for (final r in regs) r.id],
            value: to,
            display: (id) => label(regs.firstWhere((r) => r.id == id)),
            onChanged: (v) => to = v ?? to,
            label: tr('to'),
          ),
          const SizedBox(height: 12),
          FieldX(controller: amount, label: tr('amount'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          FieldX(controller: reason, label: tr('notes')),
          const SizedBox(height: 20),
        ]),
      ),
    );
    if (ok != true) return;
    try {
      await st.cash.transfer(fromId: from, toId: to, amountC: Money.fromString(amount.text), reason: reason.text.trim());
      st.changed();
      _reload();
      if (context.mounted) Toasts.show(context, tr('fin.transferDone'), kind: ToastKind.success);
    } on AppException catch (e) {
      if (context.mounted) Toasts.show(context, e.message, kind: ToastKind.error);
    }
  }

  // ------------------------------------------------------- checks / advances --
  Widget _checksSection(BuildContext context) {
    final st = context.read<AppState>();
    return HoverCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long_rounded, size: 17, color: C.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('fin.checks'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
          IconButtonX(icon: Icons.add_rounded, size: 30, color: C.primary, tooltip: tr('fin.addCheck'),
              onPressed: () => _addCheck(context, st)),
        ]),
        const SizedBox(height: 8),
        if (checks.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(tr('search.noResults'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)))
        else
          ...[for (final c in checks.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(c.direction == 'received' ? Icons.call_received_rounded : Icons.call_made_rounded,
                    size: 15, color: c.direction == 'received' ? C.success : C.secondary),
                const SizedBox(width: 9),
                Expanded(child: Text(c.party, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
                const SizedBox(width: 8),
                Text(c.dueDate.substring(0, 10), style: const TextStyle(fontSize: 11.5, color: C.textSecondary)),
                const SizedBox(width: 8),
                Flexible(child: BadgeX(
                  text: tr(c.status == 'cashed' ? 'fin.checkCashed' : (c.status == 'bounced' ? 'fin.checkBounced' : 'fin.checkPending')),
                  color: c.status == 'cashed' ? C.success : (c.status == 'bounced' ? C.danger : C.warning))),
                if (c.status == 'pending') ...[
                  const SizedBox(width: 6),
                  IconButtonX(icon: Icons.check_rounded, size: 26, color: C.success, tooltip: tr('fin.checkCashed'),
                      onPressed: () async { await st.checks.setStatus(c.id, 'cashed'); st.changed(); _reload(); }),
                  IconButtonX(icon: Icons.close_rounded, size: 26, color: C.danger, tooltip: tr('fin.checkBounced'),
                      onPressed: () async { await st.checks.setStatus(c.id, 'bounced'); st.changed(); _reload(); }),
                ],
              ]),
            )],
      ]),
    );
  }

  Future<void> _addCheck(BuildContext context, AppState st) async {
    final party = TextEditingController();
    final amount = TextEditingController();
    final checkNo = TextEditingController();
    final bank = TextEditingController();
    final due = TextEditingController();
    String direction = 'received';
    final ok = await formDialog<bool>(context,
      title: tr('fin.addCheck'),
      width: 470,
      body: (ctx) => StatefulBuilder(builder: (ctx, setD) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedX<String>(
            options: [('received', tr('fin.checkReceived')), ('issued', tr('fin.checkIssued'))],
            selected: direction,
            onChanged: (v) => setD(() => direction = v),
          ),
          const SizedBox(height: 14),
          FieldX(controller: party, label: tr('fin.checkParty')),
          const SizedBox(height: 12),
          FieldX(controller: amount, label: tr('amount'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FieldX(controller: checkNo, label: tr('fin.checkNo'))),
            const SizedBox(width: 10),
            Expanded(child: FieldX(controller: bank, label: tr('fin.bank'))),
          ]),
          const SizedBox(height: 12),
          FieldX(
            controller: due, label: tr('fin.dueDate'),
            keyboardType: TextInputType.datetime,
            suffix: IconButtonX(icon: Icons.calendar_month_rounded, size: 30, onPressed: () async {
              final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) due.text = d.toIso8601String().substring(0, 10);
            }),
          ),
          const SizedBox(height: 20),
        ]),
      )),
    );
    if (ok != true) return;
    try {
      await st.checks.add(CheckRec(
        direction: direction, party: party.text.trim(), amountC: Money.fromString(amount.text),
        checkNo: checkNo.text.trim(), bank: bank.text.trim(),
        issuedAt: Dates.iso(DateTime.now()), dueDate: due.text.trim(),
      ));
      await st.settings.audit('check_add', 'checks', 0, party.text.trim());
      st.changed();
      _reload();
      if (context.mounted) Toasts.show(context, tr('success'), kind: ToastKind.success);
    } on AppException catch (e) {
      if (context.mounted) Toasts.show(context, e.message, kind: ToastKind.error);
    }
  }

  Widget _advancesSection(BuildContext context) {
    final st = context.read<AppState>();
    return HoverCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.badge_outlined, size: 17, color: C.warning),
          const SizedBox(width: 8),
          Expanded(child: Text(tr('fin.advances'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
          IconButtonX(icon: Icons.add_rounded, size: 30, color: C.primary, tooltip: tr('fin.addAdvance'),
              onPressed: () => _addAdvance(context, st)),
        ]),
        const SizedBox(height: 8),
        if (advances.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(tr('search.noResults'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)))
        else
          ...[for (final a in advances.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                const Icon(Icons.person_outline_rounded, size: 15, color: C.textSecondary),
                const SizedBox(width: 9),
                Expanded(child: Text(a.employee, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5))),
                const SizedBox(width: 8),
                Text(Money.fmt(a.amountC), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Flexible(child: BadgeX(
                  text: a.status == 'settled' ? tr('fin.settled') : tr('fin.open'),
                  color: a.status == 'settled' ? C.success : C.warning)),
                if (a.status == 'open') ...[
                  const SizedBox(width: 6),
                  IconButtonX(icon: Icons.done_all_rounded, size: 26, color: C.success, tooltip: tr('fin.settle'),
                      onPressed: () => _settleAdvance(context, st, a)),
                ],
              ]),
            )],
      ]),
    );
  }

  Future<void> _settleAdvance(BuildContext context, AppState st, AdvanceRec a) async {
    final remaining = a.amountC - a.settledC;
    final amount = TextEditingController(text: (remaining / Money.centsPerUnit).toStringAsFixed(2));
    final ok = await formDialog<bool>(context,
      title: '${tr('fin.settle')} \u2014 ${a.employee}',
      width: 420,
      body: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tr('remaining'), style: const TextStyle(fontSize: 13, color: C.textSecondary)),
            Text(Money.fmt(remaining), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.primary)),
          ]),
          const SizedBox(height: 14),
          FieldX(controller: amount, label: tr('amount'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
        ]),
      ),
    );
    if (ok != true) return;
    await st.advances.settle(a.id, Money.fromString(amount.text));
    st.changed();
    _reload();
    if (context.mounted) Toasts.show(context, tr('fin.advanceDone'), kind: ToastKind.success);
  }

  Future<void> _addAdvance(BuildContext context, AppState st) async {
    final employee = TextEditingController();
    final amount = TextEditingController();
    final ok = await formDialog<bool>(context,
      title: tr('fin.addAdvance'),
      width: 420,
      body: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldX(controller: employee, label: tr('fin.employee')),
          const SizedBox(height: 12),
          FieldX(controller: amount, label: tr('amount'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
        ]),
      ),
    );
    if (ok != true) return;
    try {
      await st.advances.add(employee: employee.text.trim(), amountC: Money.fromString(amount.text));
      await st.settings.audit('advance_add', 'advances', 0, employee.text.trim());
      st.changed();
      _reload();
      if (context.mounted) Toasts.show(context, tr('success'), kind: ToastKind.success);
    } on AppException catch (e) {
      if (context.mounted) Toasts.show(context, e.message, kind: ToastKind.error);
    }
  }

  // ----------------------------------------------------------------- panels --
  Widget _historyCard(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('cash.history'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (history.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text(tr('cash.noHistory'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)))
        else
          ...[for (final r in history.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: r.status == 'open' ? C.success : (r.diffC == 0 ? C.primary : (r.diffC! > 0 ? C.warning : C.danger)),
                  shape: BoxShape.circle,
                )),
                const SizedBox(width: 9),
                Expanded(child: Text(r.openedAt.substring(0, 10), style: const TextStyle(fontSize: 12.5))),
                Text(Money.fmt(r.status == 'open' ? r.openingC : r.countedC ?? r.openingC),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                if (r.status == 'closed' && r.diffC != 0)
                  Text('${r.diffC! > 0 ? '+' : ''}${Money.fmt(r.diffC!)}',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: r.diffC! > 0 ? C.warning : C.danger)),
              ]),
            )],
      ]),
    );
  }

  Widget _paymentsCard() {
    return HoverCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tr('fin.payments'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          Flexible(child: Text('${tr('fin.receivedMonth')}: ${Money.fmt(paymentsInC)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.success))),
          const SizedBox(width: 8),
          Flexible(child: Text('${tr('fin.paidMonth')}: ${Money.fmt(paymentsOutC)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.danger))),
        ]),
        const SizedBox(height: 10),
        if (moves.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text(tr('cash.noMoves'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)))
        else
          ...[for (final m in moves.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(m.type == 'in' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    size: 15, color: m.type == 'in' ? C.success : C.danger),
                const SizedBox(width: 9),
                Expanded(child: Text(m.reason.isEmpty ? tr('cash.move') : m.reason,
                    style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('${m.type == 'in' ? '+' : '-'}${Money.fmt(m.amountC)}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: m.type == 'in' ? C.success : C.danger)),
              ]),
            )],
      ]),
    );
  }

  Future<void> _cashMove(BuildContext context, AppState st, {required bool cashIn}) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final ok = await formDialog<bool>(context,
      title: cashIn ? tr('cash.in') : tr('cash.out'),
      width: 420,
      body: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldX(controller: amount, label: tr('amount'), keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          FieldX(controller: reason, label: tr('notes')),
          const SizedBox(height: 20),
        ]),
      ),
    );
    if (ok != true) return;
    final cents = Money.fromString(amount.text);
    if (cents <= 0) {
      if (mounted) Toasts.show(context, tr('error'), kind: ToastKind.error);
      return;
    }
    try {
      await st.cash.manualMove(cashIn: cashIn, amountC: cents, reason: reason.text.trim());
      await st.settings.audit(cashIn ? 'cash_in' : 'cash_out', 'cash_movements', 0, Money.fmt(cents));
      st.changed();
      _reload();
      if (mounted) Toasts.show(context, tr('success'), kind: ToastKind.success);
    } on AppException catch (e) {
      if (mounted) Toasts.show(context, e.message, kind: ToastKind.error);
    }
  }
}
