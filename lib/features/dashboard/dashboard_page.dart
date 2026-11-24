import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/models/models.dart';

/// Real database-driven dashboard: KPIs, charts, quick actions, activity.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _range = 30;
  bool _loaded = false;
  bool _subscribed = false;
  String? _error;
  int revenue = 0, salesCount = 0, gross = 0, net = 0, expenses = 0;
  int products = 0, lowStock = 0, custDebt = 0, supDebt = 0, stockValue = 0;
  List<MapEntry<String, int>> daily = const [];
  List<(String, int, int, int)> monthly = const [];
  List<(String, int)> topProducts = const [];
  List<(String, int)> byMethod = const [];
  List<Sale> recentSales = const [];
  List<Payment> recentPayments = const [];
  List<StockMovement> recentMovements = const [];

  (String, String) get _period {
    final now = DateTime.now();
    final to = Dates.dayEnd(now);
    final from = switch (_range) {
      0 => Dates.dayStart(now),
      7 => Dates.iso(DateTime(now.year, now.month, now.day - 6)),
      _ => Dates.iso(DateTime(now.year, now.month, 1)),
    };
    return (from, to);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_subscribed) {
      _subscribed = true;
      context.read<AppState>().addListener(_reloadOnNotify);
      _load();
    }
  }

  void _reloadOnNotify() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final st = context.read<AppState>();
    final (from, to) = _period;
    final today = Dates.dayEnd(DateTime.now());
    try {
    final r = await Future.wait([
      st.analytics.salesSum(from, to),
      st.analytics.salesCount(from, to),
      st.analytics.grossProfitC(from, to),
      st.analytics.netProfitC(from, to),
      st.analytics.expensesC(from, to),
      st.inventory.productCount(),
      st.inventory.lowStockCount(),
      st.people.totalCustomerDebt(),
      st.people.totalSupplierDebt(),
      st.inventory.stockValueC(),
      st.analytics.dailySeries(14, today),
      st.analytics.monthlySeries(12),
      st.analytics.topProducts(limitN: 6),
      st.analytics.salesByMethod(from, to),
      st.analytics.recentSales(limit: 6),
      st.analytics.recentPayments(limit: 6),
      st.analytics.recentMovements(limit: 6),
    ]);
    if (!mounted) return;
    setState(() {
      revenue = r[0] as int;
      salesCount = r[1] as int;
      gross = r[2] as int;
      net = r[3] as int;
      expenses = r[4] as int;
      products = r[5] as int;
      lowStock = r[6] as int;
      custDebt = r[7] as int;
      supDebt = r[8] as int;
      stockValue = r[9] as int;
      daily = r[10] as List<MapEntry<String, int>>;
      monthly = r[11] as List<(String, int, int, int)>;
      topProducts = r[12] as List<(String, int)>;
      byMethod = r[13] as List<(String, int)>;
      recentSales = r[14] as List<Sale>;
      recentPayments = r[15] as List<Payment>;
      recentMovements = r[16] as List<StockMovement>;
      _loaded = true;
    });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loaded = true; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorStateX(message: _error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(tr('nav.overview'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            SegmentedX<int>(
              options: [(0, tr('today')), (7, tr('thisWeek')), (30, tr('thisMonth'))],
              selected: _range,
              onChanged: (v) { setState(() => _range = v); _load(); },
            ),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: KpiCard(title: tr('kpi.revenue'), value: Money.fmt(revenue), icon: 'revenue', color: C.primary)),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(title: tr('kpi.totalSales'), value: Money.fmt(salesCount), icon: 'sales', color: C.secondary, subtitle: '$salesCount')),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(title: tr('kpi.grossProfit'), value: Money.fmt(gross), icon: 'profit', color: C.accent)),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(title: tr('kpi.netProfit'), value: Money.fmt(net), icon: 'net', color: net >= 0 ? C.success : C.danger)),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(title: tr('kpi.expenses'), value: Money.fmt(expenses), icon: 'expense', color: C.warning)),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: KpiCard(title: tr('kpi.products'), value: '$products', icon: 'products', color: C.primary, subtitle: Money.fmt(stockValue))),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(title: tr('kpi.lowStock'), value: '$lowStock', icon: 'lowstock', color: lowStock > 0 ? C.warning : C.success)),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(title: tr('kpi.customerDebt'), value: Money.fmt(custDebt), icon: 'customers', color: C.danger)),
            const SizedBox(width: 12),
            Expanded(child: KpiCard(title: tr('kpi.supplierDebt'), value: Money.fmt(supDebt), icon: 'suppliers', color: C.secondary)),
            const SizedBox(width: 12),
            Expanded(child: _quickActions(context)),
          ]),
          const SizedBox(height: 20),
          if (products == 0)
            EmptyStateX(
              title: tr('dash.startTitle'),
              body: tr('dash.startBody'),
              icon: Icons.storefront_rounded,
              action: AppButton(label: tr('qa.addProduct'), icon: Icons.add, onPressed: () => widget.onNavigate(2)),
            )
          else ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _chartCard(tr('chart.daily'), _dailyChart(), height: 250)),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: _chartCard(tr('chart.monthly'), _monthlyLineChart(), height: 250)),
            ]),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _chartCard(tr('chart.topProducts'), _topProductsList(), height: 240)),
              const SizedBox(width: 14),
              Expanded(child: _chartCard(tr('chart.byPayment'), _methodsList(), height: 240)),
            ]),
            const SizedBox(height: 14),
            _recentSection(context),
          ],
        ]),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    final actions = [
      (Icons.point_of_sale_rounded, tr('qa.newSale'), 1),
      (Icons.add_shopping_cart_rounded, tr('qa.addProduct'), 2),
      (Icons.person_add_alt_1_rounded, tr('qa.addCustomer'), 5),
      (Icons.local_shipping_rounded, tr('qa.newPurchase'), 7),
      (Icons.receipt_long_rounded, tr('qa.addExpense'), 8),
      (Icons.receipt_rounded, tr('qa.createInvoice'), 9),
    ];
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('quick.actions'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
        const Spacer(),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (icon, label, idx) in actions)
            ActionChip(
              avatar: Icon(icon, size: 15, color: C.primary),
              label: Text(label, style: const TextStyle(fontSize: 11.5)),
              onPressed: () => widget.onNavigate(idx),
            ),
        ]),
      ]),
    );
  }
}

extension _DashCharts on _DashboardPageState {
  Widget _chartCard(String title, Widget child, {double height = 240}) {
    return HoverCard(
      child: SizedBox(
        height: height,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(child: child),
        ]),
      ),
    );
  }

  Widget _dailyChart() {
    if (daily.isEmpty) return const EmptyStateX(title: '—', body: '', icon: Icons.show_chart);
    final spots = <FlSpot>[
      for (var i = 0; i < daily.length; i++) FlSpot(i.toDouble(), daily[i].value / Money.centsPerUnit),
    ];
    final maxY = spots.map((s) => s.y).fold(1.0, (a, b) => b > a ? b : a);
    return LineChart(
      LineChartData(
        minY: 0, maxY: maxY * 1.2,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => const FlLine(color: C.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 52, interval: (maxY / 4).clamp(1, double.infinity), getTitlesWidget: (v, _) => Text(_kFmt(v), style: const TextStyle(fontSize: 10, color: C.textSecondary)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, interval: daily.length > 8 ? 2 : 1, getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= daily.length) return const SizedBox.shrink();
            return Text(daily[i].key.substring(8), style: const TextStyle(fontSize: 10, color: C.textSecondary));
          })),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => [
            for (final s in spots)
              LineTooltipItem(Money.fmt((s.y * Money.centsPerUnit).round()), const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots, isCurved: true, barWidth: 2.6, color: C.primary,
            preventCurveOverShooting: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [C.primary.withValues(alpha: .18), C.primary.withValues(alpha: 0)])),
          ),
        ],
      ),
    );
  }

  Widget _monthlyLineChart() {
    if (monthly.isEmpty) return const EmptyStateX(title: '—', body: '', icon: Icons.show_chart);
    final salesSpots = <FlSpot>[];
    final profitSpots = <FlSpot>[];
    for (var i = 0; i < monthly.length; i++) {
      final (ym, sales, purch, exp) = monthly[i];
      profitSpots.add(FlSpot(i.toDouble(), (sales - purch - exp) / Money.centsPerUnit));
      salesSpots.add(FlSpot(i.toDouble(), sales / Money.centsPerUnit));
    }
    final maxY = [...salesSpots, ...profitSpots].map((s) => s.y).fold(1.0, (a, b) => b > a ? b : a);
    return LineChart(
      LineChartData(
        minY: 0, maxY: maxY * 1.2,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => const FlLine(color: C.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 52, interval: (maxY / 4).clamp(1, double.infinity), getTitlesWidget: (v, _) => Text(_kFmt(v), style: const TextStyle(fontSize: 10, color: C.textSecondary)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= monthly.length) return const SizedBox.shrink();
            return Text(monthly[i].$1.substring(5), style: const TextStyle(fontSize: 10, color: C.textSecondary));
          })),
        ),
        lineBarsData: [
          LineChartBarData(spots: salesSpots, isCurved: true, barWidth: 2.4, color: C.primary, dotData: const FlDotData(show: false)),
          LineChartBarData(spots: profitSpots, isCurved: true, barWidth: 2.4, color: C.accent, dotData: const FlDotData(show: false)),
        ],
      ),
    );
  }

  String _kFmt(double v) {
    final units = v / 1000;
    if (units.abs() >= 1) return "${units.toStringAsFixed(units.abs() >= 10 ? 0 : 1)}k";
    return v.toStringAsFixed(0);
  }

  Widget _topProductsList() {
    if (topProducts.isEmpty) return EmptyStateX(title: tr('noData'), body: '', icon: Icons.inventory_2_outlined);
    final maxQ = topProducts.map((e) => e.$2).fold(1, (a, b) => b > a ? b : a);
    return ListView(children: [
      for (final (name, qty) in topProducts) ...[
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
            Text('x$qty', style: const TextStyle(fontSize: 12, color: C.textSecondary)),
          ]),
          const SizedBox(height: 5),
          TweenAnimationBuilder<double>(
            tween: Tween(end: qty / maxQ),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Container(
              height: 7,
              width: double.infinity,
              alignment: AlignmentDirectional.centerStart,
              decoration: BoxDecoration(
                color: C.border.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                widthFactor: v.clamp(0.02, 1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [C.primary, C.secondary]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
      ],
    ]);
  }

  Widget _methodsList() {
    if (byMethod.isEmpty) return EmptyStateX(title: tr('noData'), body: '', icon: Icons.credit_card);
    final total = byMethod.map((e) => e.$2).fold(1, (a, b) => a + b);
    const colors = [C.primary, C.accent, C.secondary, C.warning, C.success, C.danger];
    return ListView(children: [
      for (var i = 0; i < byMethod.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(_methodLabel(byMethod[i].$1), style: const TextStyle(fontSize: 12.5))),
              Text('${(byMethod[i].$2 * 100 / total).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Text(Money.fmt(byMethod[i].$2), style: const TextStyle(fontSize: 12, color: C.textSecondary)),
            ]),
          ]),
        ),
    ]);
  }

  String _methodLabel(String m) {
    final map = {
      'cash': tr('cash'), 'card': tr('card'), 'transfer': tr('transfer'),
      'partial': tr('partial'), 'credit': tr('credit'),
    };
    return map[m] ?? m;
  }

  Widget _recentSection(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _recentList(tr('recent.sales'), recentSales.map((s) => (
            s.invoiceNo,
            Money.fmt(s.totalC),
            '${Dates.parse(s.saleAt).day.toString().padLeft(2, '0')}/${Dates.parse(s.saleAt).month.toString().padLeft(2, '0')}',
            s.status == 'cancelled',
          )).toList(), 9)),
      const SizedBox(width: 14),
      Expanded(child: _recentList(tr('recent.payments'), recentPayments.map((p) => (
            '${p.kind == 'refund' ? '-' : '+'}${Money.fmt(p.amountC)}',
            _methodLabel(p.method),
            '${Dates.parse(p.paidAt).day.toString().padLeft(2, '0')}/${Dates.parse(p.paidAt).month.toString().padLeft(2, '0')}',
            p.kind == 'refund',
          )).toList(), 10)),
      const SizedBox(width: 14),
      Expanded(child: _recentList(tr('recent.movements'), recentMovements.map((m) => (
            m.productName.isNotEmpty ? m.productName : '#${m.productId}',
            '${m.type == 'in' ? '+' : '-'}${m.qty}',
            '${Dates.parse(m.movedAt).day.toString().padLeft(2, '0')}/${Dates.parse(m.movedAt).month.toString().padLeft(2, '0')}',
            m.type != 'in',
          )).toList(), 4)),
    ]);
  }

  Widget _recentList(String title, List<(String, String, String, bool)> rows, int navIdx) {
    return HoverCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton(onPressed: () => widget.onNavigate(navIdx), child: Text(tr('details'), style: const TextStyle(fontSize: 12))),
        ]),
        if (rows.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Text(tr('noData'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)))
        else
          ...[for (final (a, b, day, neg) in rows.take(5)) Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Text(day, style: const TextStyle(fontSize: 11, color: C.textSecondary)),
              const SizedBox(width: 10),
              Expanded(child: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              Text(b, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: neg ? C.danger : C.success)),
            ]),
          )],
      ]),
    );
  }
}
