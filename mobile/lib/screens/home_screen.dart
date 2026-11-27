import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../l10n.dart';
import '../store.dart';
import '../ui_kit.dart';
import 'pair_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int tabIndex = 0;
  bool loading = true;
  String? error;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: .97,
    upperBound: 1.0,
  )..repeat(reverse: true);
  Timer? _autoTimer;
  Map<String, dynamic>? summary;
  List<dynamic> daily = [];
  List<dynamic> top = [];
  List<dynamic> sales = [];
  List<dynamic> products = [];
  Map<String, dynamic>? debts;

  @override
  void initState() {
    super.initState();
    _refresh();
    _autoTimer = Timer.periodic(
        const Duration(seconds: 30), (_) { if (mounted && !loading) _refresh(); });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() { loading = summary == null; error = null; });
    final api = Store.client();
    try {
      final results = await Future.wait([
        api.summary(),
        api.daily(),
        api.top(),
        api.sales(),
        api.products('all'),
        api.debts(),
      ]);
      if (!mounted) return;
      setState(() {
        summary = results[0] as Map<String, dynamic>;
        daily = results[1] as List<dynamic>;
        top = results[2] as List<dynamic>;
        sales = results[3] as List<dynamic>;
        products = results[4] as List<dynamic>;
        debts = results[5] as Map<String, dynamic>;
        loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      // Pairing may be stale (server restarted with a new code).
      if (e.code == 'unauthorized') {
        await Store.clear();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const PairScreen()));
        return;
      }
      setState(() { error = e.message(gAr); loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = '$e'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 10),
          child: BrandAvatar(
              label: (summary?['business'] as String? ?? 'D')),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(summary?['business'] as String? ?? t('app'),
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: C.textPrimary)),
          Text(t('app'), style: const TextStyle(fontSize: 10.5, color: C.textSecondary)),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              gAr = !gAr;
              await Store.saveLanguage(gAr);
              if (!mounted) return;
              setState(() {});
            },
            child: Text(t('lang'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                                    begin: const Offset(0, .04), end: Offset.zero)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(tabIndex),
                          child: switch (tabIndex) {
                            0 => _dashboard(),
                            1 => _salesList(),
                            2 => _stock(),
                            _ => _debts(),
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        animationDuration: const Duration(milliseconds: 360),
        onDestinationSelected: (i) => setState(() { tabIndex = i; _refresh(); }),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_rounded), label: t('tab.home')),
          NavigationDestination(icon: const Icon(Icons.receipt_long_rounded), label: t('tab.sales')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_rounded), label: t('tab.stock')),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_rounded), label: t('tab.debts')),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _pulse,
        child: FloatingActionButton.extended(
          heroTag: 'refresh',
          backgroundColor: C.primary,
          foregroundColor: Colors.white,
          elevation: 5,
          tooltip: t('refresh'),
          onPressed: _refresh,
          icon: loading
              ? const SizedBox(width: 17, height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh_rounded),
          label: Text(t('refresh'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 44, color: C.textSecondary),
            const SizedBox(height: 10),
            Text(error ?? t('offline'), textAlign: TextAlign.center,
                style: const TextStyle(color: C.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.primary),
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(t('refresh')),
            ),
          ]),
        ),
      );

  Map<String, dynamic> _win(String key) =>
      summary?[key] as Map<String, dynamic>? ?? {};

  Widget _dashboard() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              KpiTile(title: t('kpi.todayRev'), color: C.primary, value: Money.fmt(_n(_win('today')['revenue_c']), ar: gAr)),
              KpiTile(title: t('kpi.todayCount'), color: C.secondary, value: '${_n(_win('today')['count'])}'),
              KpiTile(title: t('kpi.weekRev'), color: C.accent, value: Money.fmt(_n(_win('week')['revenue_c']), ar: gAr)),
              KpiTile(title: t('kpi.monthNet'), color: _n(_win('month')['net_c']) >= 0 ? C.success : C.danger, value: Money.fmt(_n(_win('month')['net_c']), ar: gAr)),
              KpiTile(title: t('kpi.custDebt'), color: C.warning, value: Money.fmt(_n(summary?['customer_debt_c']), ar: gAr)),
              KpiTile(title: t('kpi.supDebt'), color: C.warning, value: Money.fmt(_n(summary?['supplier_debt_c']), ar: gAr)),
              KpiTile(title: t('kpi.lowStock'), color: C.danger, value: '${_n(summary?['low_stock'])}'),
              KpiTile(title: t('kpi.dueChecks'), color: C.secondary, value: '${_n(summary?['due_checks'])}'),
            ],
          ),
          const SizedBox(height: 14),
          MCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('daily.14'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.textPrimary)),
              const SizedBox(height: 16),
              SizedBox(height: 160, child: _dailyChart()),
            ]),
          ),
          const SizedBox(height: 14),
          MCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('top.title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.textPrimary)),
              const SizedBox(height: 8),
              if (top.isEmpty) Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(t('sales.none'), style: const TextStyle(fontSize: 12, color: C.textSecondary)),
              )
              else
                ...top.take(8).map((e) {
                  final m = e as Map<String, dynamic>;
                  final name = _name(m);
                  final profit = _n(m['profit_c']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5))),
                      Text('${_n(m['qty'])} ×', style: const TextStyle(fontSize: 12, color: C.textSecondary)),
                      const SizedBox(width: 10),
                      Text(Money.fmt(profit, ar: gAr), style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: profit >= 0 ? C.success : C.danger)),
                    ]),
                  );
                }),
            ]),
          ),
        ],
      );

  Widget _dailyChart() {
    if (daily.isEmpty) {
      return Center(child: Text(t('sales.none'), style: const TextStyle(fontSize: 12, color: C.textSecondary)));
    }
    final spots = <FlSpot>[
      for (var i = 0; i < daily.length; i++)
        FlSpot(i.toDouble(), (_n((daily[i] as Map)['revenue_c']) / 100).toDouble()),
    ];
    return LineChart(LineChartData(
      minY: 0,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem(Money.fmt(s.y.round() * 100, ar: gAr),
                  const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      gridData: FlGridData(drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(color: C.border, strokeWidth: 1)),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, reservedSize: 34, interval: (daily.length / 5).clamp(1, 99).toDouble(),
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= daily.length) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(shortDay('${(daily[i] as Map)['day']}', gAr),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9, color: C.textSecondary)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 2.6,
          color: C.primary,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: C.primary.withValues(alpha: .09)),
        ),
      ],
    ));
  }

  Widget _salesList() {
    if (sales.isEmpty) return _centerEmpty(t('sales.none'));
    return Column(children: [
      for (final raw in sales)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MCard(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${raw['invoice_no']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: C.textPrimary)),
                  const SizedBox(height: 3),
                  Text('${(raw['at'] as String? ?? '').substring(0, 10)} · ${_methodName(raw['method'] as String? ?? '')} · ${raw['customer'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: C.textSecondary)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(Money.fmt(_n(raw['total_c']), ar: gAr),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.primary)),
              const SizedBox(width: 8),
              StatusBadge(
                text: raw['status'] == 'cancelled' ? t('status.cancelled') : t('status.completed'),
                color: raw['status'] == 'cancelled' ? C.danger : C.success,
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _stock() {
    if (products.isEmpty) return _centerEmpty(t('debts.none'));
    final low = [
      for (final p in products)
        if (_n(p['stock']) <= _n(p['min'])) p,
    ];
    final shown = [
      ...low,
      ...[for (final p in products) if (_n(p['stock']) > _n(p['min'])) p],
    ];
    return Column(children: [
      for (final raw in shown.take(120))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MCard(
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: (_n(raw['stock']) <= 0 ? C.danger : _n(raw['stock']) <= _n(raw['min']) ? C.warning : C.accent).withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text('${_n(raw['stock'])}', style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800,
                    color: _n(raw['stock']) <= 0 ? C.danger : _n(raw['stock']) <= _n(raw['min']) ? C.warning : C.accent)),
              ),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name(raw), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${raw['sku'] ?? ''} · ${t('stock.min')}: ${_n(raw['min'])}',
                    style: const TextStyle(fontSize: 10.5, color: C.textSecondary)),
              ])),
              Text(Money.fmt(_n(raw['price_c']), ar: gAr), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
    ]);
  }

  Widget _debts() {
    final custs = debts?['customers'] as List<dynamic>? ?? [];
    final sups = debts?['suppliers'] as List<dynamic>? ?? [];
    if (custs.isEmpty && sups.isEmpty) return _centerEmpty(t('debts.none'));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (custs.isNotEmpty) ...[
        _section(t('debts.customers')),
        for (final raw in custs) _debtRow(raw),
      ],
      if (sups.isNotEmpty) ...[
        _section(t('debts.suppliers')),
        for (final raw in sups) _debtRow(raw),
      ],
    ]);
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.textPrimary)),
      );

  Widget _debtRow(Map<String, dynamic> raw) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MCard(
          child: Row(children: [
            const Icon(Icons.person_outline_rounded, size: 20, color: C.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(_name(raw), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
            Text(Money.fmt(_n(raw['debt_c']), ar: gAr),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: C.danger)),
          ]),
        ),
      );

  Widget _centerEmpty(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(children: [
            Icon(Icons.inbox_rounded, size: 44, color: C.textSecondary.withValues(alpha: .45)),
            const SizedBox(height: 10),
            Text(msg, style: const TextStyle(color: C.textSecondary, fontSize: 13)),
          ]),
        ),
      );
}

String _name(Map<String, dynamic> m) {
  final ar = m['name_ar'] as String? ?? '';
  final fr = m['name_fr'] as String? ?? '';
  if (gAr) return ar.isNotEmpty ? ar : (fr.isNotEmpty ? fr : '—');
  return fr.isNotEmpty ? fr : (ar.isNotEmpty ? ar : '—');
}

int _n(Object? v) => v is int ? v : (v as num? ?? 0).toInt();

String _methodName(String key) => t('method.${key.isEmpty ? 'cash' : key}');
