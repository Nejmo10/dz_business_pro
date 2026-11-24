import 'dart:io';
import 'dart:convert' show utf8;

import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../printing/print_service.dart';

/// Reporting: 10 report types generated from real database records, with
/// date-range and category filters, CSV and PDF export.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String report = 'sales';
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime to = DateTime.now();
  int? categoryId;
  List<(String, String)> categories = [];
  List<String> headers = [];
  List<List<String>> rows = [];
  bool loading = false;
  bool ran = false;

  static const Map<String, String> _labels = {
    'sales': 'rep.sales', 'purchases': 'rep.purchases', 'expenses': 'rep.expenses',
    'profits': 'rep.profits', 'inventory': 'rep.inventory', 'customers': 'rep.customers',
    'suppliers': 'rep.suppliers', 'debts': 'rep.debts', 'payments': 'rep.payments',
    'performance': 'rep.performance',
  };

  String get _fromIso => from.toIso8601String().substring(0, 10);
  String get _toIso => DateTime(to.year, to.month, to.day, 23, 59, 59).toIso8601String().substring(0, 19);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (categories.isEmpty) _loadCategories();
  }

  Future<void> _loadCategories() async {
    final st = context.read<AppState>();
    final dbrows = await st.database.db.query('categories', orderBy: 'name_fr');
    if (!mounted) return;
    setState(() {
      categories = [for (final r in dbrows) ('${r['id']}', (r['name_fr'] as String?) ?? '')];
    });
  }

  Future<void> _run() async {
    setState(() { loading = true; });
    final st = context.read<AppState>();
    final db = st.database.db;
    final f = _fromIso, t = _toIso;
    final arName = gIsArabic;
    List<String> header;
    List<List<String>> data;

    switch (report) {
      case 'purchases':
        final r = await st.database.db.rawQuery('''
          SELECT pu.invoice_no, pu.purchase_at, COALESCE(sp.name_fr,'-') AS sup,
                 pu.total_c, pu.paid_c, pu.status
          FROM purchases pu LEFT JOIN suppliers sp ON sp.id = pu.supplier_id
          WHERE pu.purchase_at >= ? AND pu.purchase_at <= ? ORDER BY pu.id DESC LIMIT 1000''', [f, t]);
        header = [tr('reference'), tr('date'), tr('supplier'), tr('total'), tr('paid'), tr('remaining'), tr('status')];
        data = [for (final m in r) [
          '${m['invoice_no']}', m['purchase_at'].toString().substring(0, 16).replaceAll('T', ' '),
          '${m['sup']}', Money.fmt(m['total_c'] as int? ?? 0), Money.fmt(m['paid_c'] as int? ?? 0),
          Money.fmt((m['total_c'] as int? ?? 0) - (m['paid_c'] as int? ?? 0)),
          m['status'] == 'cancelled' ? tr('cancelled') : tr('completed'),
        ]];
      case 'expenses':
        final r = await db.rawQuery('''
          SELECT e.paid_at, COALESCE(ec.name_fr,'-') AS cat, e.description, e.method, e.amount_c
          FROM expenses e LEFT JOIN expense_categories ec ON ec.id = e.category_id
          WHERE e.paid_at >= ? AND e.paid_at <= ? ORDER BY e.id DESC LIMIT 1000''', [f, t]);
        header = [tr('date'), tr('exp.category'), tr('description'), tr('method'), tr('amount')];
        data = [for (final m in r) [
          m['paid_at'].toString().substring(0, 10), '${m['cat']}', '${m['description'] ?? ''}',
          '${m['method']}', Money.fmt(m['amount_c'] as int? ?? 0),
        ]];
      case 'profits':
        final r = await db.rawQuery('''
          SELECT substr(s.sale_at,1,10) AS d, SUM(s.total_c) AS rev, COUNT(*) AS cnt
          FROM sales s WHERE s.status='completed' AND s.sale_at >= ? AND s.sale_at <= ?
          GROUP BY d ORDER BY d''', [f, t]);
        header = [tr('date'), tr('salesCount2'), tr('kpi.revenue'), tr('kpi.grossProfit'), tr('kpi.expenses'), tr('kpi.netProfit')];
        data = [];
        for (final m in r) {
          final day = m['d'] as String;
          final gross = await st.analytics.grossProfitC('${day}T00:00:00', '${day}T23:59:59');
          final exp = await st.analytics.expensesC('${day}T00:00:00', '${day}T23:59:59');
          data.add([
            day, '${m['cnt']}', Money.fmt(m['rev'] as int? ?? 0), Money.fmt(gross), Money.fmt(exp), Money.fmt(gross - exp),
          ]);
        }
      case 'inventory':
        final catFilter = categoryId != null ? 'AND p.category_id = ?' : '';
        final args = categoryId != null ? [categoryId] : <Object?>[];
        final r = await db.rawQuery('''
          SELECT p.name_fr, p.name_ar, p.sku, p.stock_qty, p.cost_c, p.min_stock, COALESCE(c.name_fr,'-') AS cat
          FROM products p LEFT JOIN categories c ON c.id = p.category_id
          WHERE p.archived = 0 $catFilter ORDER BY p.stock_qty ASC''', args);
        header = [tr('name'), tr('sku'), tr('category'), tr('stock'), tr('min'), tr('cost'), tr('inv.value')];
        data = [for (final m in r) [
          '${m['name_fr']}', '${m['sku'] ?? ''}', '${m['cat']}', '${m['stock_qty']}',
          '${m['min_stock'] ?? 0}', Money.fmt(m['cost_c'] as int? ?? 0),
          Money.fmt((m['stock_qty'] as int? ?? 0) * (m['cost_c'] as int? ?? 0)),
        ]];
      case 'customers':
        final r = await db.rawQuery('''
          SELECT c.name_fr, COUNT(s.id) AS cnt, COALESCE(SUM(s.total_c),0) AS total,
                 COALESCE(SUM(s.total_c - s.paid_c),0) AS due
          FROM customers c LEFT JOIN sales s ON s.customer_id = c.id
            AND s.status='completed' AND s.sale_at >= ? AND s.sale_at <= ?
          GROUP BY c.id ORDER BY total DESC LIMIT 500''', [f, t]);
        header = [tr('customer'), tr('salesCount2'), tr('total'), tr('remaining')];
        data = [for (final m in r) [
          '${m['name_fr']}', '${m['cnt']}', Money.fmt(m['total'] as int? ?? 0), Money.fmt(m['due'] as int? ?? 0),
        ]];
      case 'suppliers':
        final r = await db.rawQuery('''
          SELECT sp.name_fr, COUNT(pu.id) AS cnt, COALESCE(SUM(pu.total_c),0) AS total,
                 COALESCE(SUM(pu.total_c - pu.paid_c),0) AS due
          FROM suppliers sp LEFT JOIN purchases pu ON pu.supplier_id = sp.id
            AND pu.status != 'cancelled' AND pu.purchase_at >= ? AND pu.purchase_at <= ?
          GROUP BY sp.id ORDER BY total DESC LIMIT 500''', [f, t]);
        header = [tr('supplier'), tr('purchases'), tr('total'), tr('remaining')];
        data = [for (final m in r) [
          '${m['name_fr']}', '${m['cnt']}', Money.fmt(m['total'] as int? ?? 0), Money.fmt(m['due'] as int? ?? 0),
        ]];
      case 'debts':
        final rc = await db.rawQuery('''
          SELECT name_fr, balance_c, credit_limit_c FROM customers
          WHERE balance_c > 0 ORDER BY balance_c DESC''');
        final rs = await db.rawQuery('''
          SELECT sp.name_fr, COALESCE(SUM(pu.total_c - pu.paid_c),0) AS due
          FROM suppliers sp JOIN purchases pu ON pu.supplier_id = sp.id
          WHERE pu.status != 'cancelled' GROUP BY sp.id HAVING due > 0 ORDER BY due DESC''');
        header = [tr('type'), tr('name'), tr('amount'), tr('creditLimit')];
        data = [
          for (final m in rc) [tr('customer'), '${m['name_fr']}',
            Money.fmt(m['balance_c'] as int? ?? 0), Money.fmt(m['credit_limit_c'] as int? ?? 0)],
          for (final m in rs) [tr('supplier'), '${m['name_fr']}', Money.fmt(m['due'] as int? ?? 0), ''],
        ];
      case 'payments':
        final r = await db.rawQuery('''
          SELECT paid_at, direction, kind, method, amount_c, notes
          FROM payments WHERE paid_at >= ? AND paid_at <= ? ORDER BY id DESC LIMIT 1000''', [f, t]);
        header = [tr('date'), tr('type'), tr('kind'), tr('method'), tr('amount'), tr('notes')];
        data = [for (final m in r) [
          m['paid_at'].toString().substring(0, 16).replaceAll('T', ' '),
          m['direction'] == 'sale' ? tr('sales') : tr('purchases'),
          m['kind'] == 'refund' ? tr('returns').toLowerCase() : tr('paid'),
          '${m['method']}', Money.fmt(m['amount_c'] as int? ?? 0), '${m['notes'] ?? ''}',
        ]];
      case 'performance':
        final catFilter = categoryId != null ? 'AND p.category_id = ?' : '';
        String nameExpr = arName ? 'si.name_ar' : 'si.name_fr';
        final args = <Object?>[f, t, if (categoryId != null) categoryId];
        final r = await db.rawQuery('''
          SELECT $nameExpr AS n, COALESCE(SUM(si.qty - si.returned_qty),0) AS q,
                 COALESCE(SUM(si.total_c),0) AS rev,
                 COALESCE(SUM(si.total_c - si.unit_cost_c*si.qty),0) AS pr
          FROM sale_items si JOIN sales s ON s.id = si.sale_id
            JOIN products p ON p.id = si.product_id
          WHERE s.status='completed' AND s.sale_at >= ? AND s.sale_at <= ? $catFilter
          GROUP BY si.product_id ORDER BY rev DESC LIMIT 200''', args);
        header = [tr('name'), tr('soldQty'), tr('kpi.revenue'), tr('kpi.grossProfit')];
        data = [for (final m in r) [
          '${m['n']}', '${m['q']}', Money.fmt(m['rev'] as int? ?? 0), Money.fmt(m['pr'] as int? ?? 0),
        ]];
      default:
        final r = await st.database.db.rawQuery('''
          SELECT s.invoice_no, s.sale_at, COALESCE(c.name_fr,'-') AS cust, s.payment_method,
                 s.total_c, s.paid_c, s.status
          FROM sales s LEFT JOIN customers c ON c.id = s.customer_id
          WHERE s.sale_at >= ? AND s.sale_at <= ? ORDER BY s.id DESC LIMIT 1000''', [f, t]);
        header = [tr('reference'), tr('date'), tr('customer'), tr('method'), tr('total'), tr('paid'), tr('remaining'), tr('status')];
        data = [for (final m in r) [
          '${m['invoice_no']}', m['sale_at'].toString().substring(0, 16).replaceAll('T', ' '),
          '${m['cust']}', '${m['payment_method']}', Money.fmt(m['total_c'] as int? ?? 0),
          Money.fmt(m['paid_c'] as int? ?? 0),
          Money.fmt((m['total_c'] as int? ?? 0) - (m['paid_c'] as int? ?? 0)),
          m['status'] == 'cancelled' ? tr('cancelled') : tr('completed'),
        ]];
    }

    if (!mounted) return;
    setState(() { headers = header; rows = data; loading = false; ran = true; });
  }

  List<double> get _widths {
    final n = headers.length;
    return [for (int i = 0; i < n; i++) i == 0 ? 2 : 1];
  }

  Future<void> _exportCsv() async {
    if (rows.isEmpty) return;
    final location = await getSaveLocation(suggestedName: 'report_$report.csv');
    if (location == null) return;
    final csv = const ListToCsvConverter().convert([
      headers,
      for (final r in rows) r,
    ]);
    await File(location.path).writeAsString('\ufeff$csv', encoding: utf8, flush: true);
    if (mounted) Toasts.show(context, '${tr('export')} — ${rows.length}', kind: ToastKind.success);
  }

  Future<void> _exportPdf() async {
    if (rows.isEmpty) return;
    final st = context.read<AppState>();
    final sub = '${tr('date')}: ${_fromIso.substring(0, 10)}  →  ${to.toIso8601String().substring(0, 10)}';
    await PrintService(st).reportPdf(tr(_labels[report]!), sub, headers, rows);
    if (mounted) Toasts.show(context, tr('export'), kind: ToastKind.success);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HoverCard(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Expanded(
              flex: 4,
              child: SmartDropdown<String>(
                label: tr('reports'),
                items: [for (final e in _labels.entries) e.key],
                value: report,
                display: (v) => tr(_labels[v]!),
                onChanged: (v) { if (v != null) setState(() { report = v; ran = false; rows = []; }); },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _dateField(context, tr('dateFrom'), from, (d) => setState(() { from = d; ran = false; })),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _dateField(context, tr('dateTo'), to, (d) => setState(() { to = d; ran = false; })),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: SmartDropdown<String>(
                label: tr('category'),
                items: ['-', for (final c in categories) c.$1],
                value: categoryId?.toString() ?? '-',
                display: (v) => v == '-' ? tr('all') : categories.firstWhere((c) => c.$1 == v).$2,
                onChanged: (v) => setState(() {
                  categoryId = (v == null || v == '-') ? null : int.tryParse(v);
                }),
              ),
            ),
            const SizedBox(width: 10),
            AppButton(label: tr('apply'), icon: Icons.play_arrow_rounded, onPressed: _run),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Text('${tr('reports')} — ${tr(_labels[report]!)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const Spacer(),
        AppButton(label: 'CSV', icon: Icons.table_view_outlined, kind: AppButtonKind.secondary, onPressed: rows.isEmpty ? null : _exportCsv),
        const SizedBox(width: 8),
        AppButton(label: 'PDF', icon: Icons.picture_as_pdf_outlined, kind: AppButtonKind.secondary, onPressed: rows.isEmpty ? null : _exportPdf),
      ]),
      const SizedBox(height: 10),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : !ran
                ? EmptyStateX(title: tr('rep.pick'), body: tr('rep.pickHint'), icon: Icons.assessment_outlined)
                : rows.isEmpty
                    ? EmptyStateX(title: tr('rep.noData'), body: tr('rep.pickHint'), icon: Icons.assessment_outlined)
                    : TableX(
                        columns: headers,
                        widths: _widths,
                        rows: [for (final r in rows) [for (final c in r) Text(c, style: const TextStyle(fontSize: 12))]],
                      ),
      ),
    ]);
  }

  Widget _dateField(BuildContext context, String label, DateTime value, ValueChanged<DateTime> onPick) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: C.bg,
          border: Border.all(color: C.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Expanded(child: Text(
            '$label: ${value.toIso8601String().substring(0, 10)}',
            style: const TextStyle(fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
          )),
          Icon(Icons.calendar_today_outlined, size: 15, color: C.textSecondary),
        ]),
      ),
    );
  }
}
