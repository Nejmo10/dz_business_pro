import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/l10n.dart';
import '../../app/state.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../../core/ui.dart';
import '../../data/database/app_database.dart';

/// Trader toolbox: user guide, database health center and the business
/// assistant. Every answer is computed from the live SQLite database.
class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});
  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  String tab = 'guide';
  bool healthRunning = false;
  List<HealthResult> health = [];
  String? healthError;
  int assistQuestion = 1;
  String assistAnswer = '';
  bool assistLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedX<String>(
        options: [
          ('guide', tr('guide.title')),
          ('health', tr('health.title')),
          ('assist', tr('assist.title')),
        ],
        selected: tab,
        onChanged: (v) => setState(() => tab = v),
      ),
      const SizedBox(height: 16),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: tab == 'guide'
            ? _guide()
            : tab == 'health'
                ? _health()
                : _assistant(),
      )),
    ]);
  }

  // -------------------------------------------------------------- guide tab --
  Widget _guide() {
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('guide.title'), subtitle: tr('guide.subtitle')),
        ..._guideSteps().map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 26, height: 26, margin: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(gradient: C.gradientPrimary, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(step.$1, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(step.$2, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: C.textPrimary)),
                  const SizedBox(height: 3),
                  Text(step.$3, style: const TextStyle(fontSize: 12.5, color: C.textSecondary, height: 1.55)),
                  const SizedBox(height: 14),
                ])),
              ]),
            )),
      ]),
    );
  }

  List<(String, String, String)> _guideSteps() {
    final ar = gIsArabic;
    return [
      ('1', ar ? 'أول تشغيل: إعداد المحل' : 'Premier lancement : configuration',
          ar ? 'يعرض البرنامج معالج التهيئة: اسم المحل، النشاط، العنوان، الهاتف، اللغة، العملة (دينار جزائري)، الضريبة وصيغة الإيصال. كل شيء يُحفَظ دائماً في قاعدة البيانات ويمكن تعديله لاحقاً من الإعدادات.'
             : "Au premier lancement, l'assistant demande : nom, activité, adresse, téléphone, langue, devise (dinar algérien), TVA et format de ticket. Tout est enregistré dans la base et modifiable dans Paramètres."),
      ('2', ar ? 'تسجيل المخزون' : 'Constituer le stock',
          ar ? 'من صفحة «المنتجات» أضِف منتجاتك: الاسم بالعربية والفرنسية، رمز SKU، الباركود، سعر الشراء وسعر البيع (وسعر الجملة)، الوحدة (قطعة/علبة/كرتون/كجم/لتر) وعدد الوحدات في الصندوق. لاستيراد قائمة كاملة استخدم زر الاستيراد CSV.'
             : 'Dans Produits, créez vos articles : noms AR/FR, SKU, code-barres, prix achat/majoré/gros, unité (pièce, boîte, carton, kg, litre) et contenu par boîte. Importez une liste complète via le bouton Importer CSV.'),
      ('3', ar ? 'تسجيل بضاعة المشتريات' : 'Enregistrer les achats',
          ar ? 'من «المشتريات» سجّل ما تشتريه من الموزعين: المورد، المنتجات، الكميات، سعر الوحدة، خصم ومصاريف النقل/التحميل. عند التأكيد يزيد المخزون تلقائياً ويُسجّل ما دفعته وما تبقى كدين على المورد.'
             : "Dans Achats, enregistrez chaque entrée : fournisseur, produits, quantités, prix unitaire, remise et frais de transport. À la confirmation, le stock augmente, le payé est enregistré et le reste devient un solde fournisseur."),
      ('4', ar ? 'البيع من نقطة البيع' : 'Vendre au comptoir',
          ar ? 'افتح «نقطة البيع»: انقر على المنتجات لإضافتها (أو امسح الباركود)، بدّل بين سعر التجزئة وسعر الجملة، اختر العميل، الخصم، طريقة الدفع (نقداً، بطاقة، تحويل، جزئي، آجل) والمبلغ المدفوع. عند التأكيد تُنشأ فاتورة برقم فريد، يُخصم المخزون، تُحسب نقاط الولاء ويتحدَّث صندوق النقد — كلها في معاملة واحدة لا تنقسم أبداً.'
             : "Au POS : cliquez les produits (ou scannez le code-barres), basculez retail/prix de gros, choisissez le client, la remise, le mode de paiement (espèces, carte, virement, partiel, crédit). À la validation : facture numérotée, stock décrémenté, points fidélité et caisse mis à jour — le tout en une seule transaction atomique."),
      ('5', ar ? 'الفواتير والأوراق' : 'Factures & documents',
          ar ? 'من صفحة «الفواتير» راجع كل عملية، أعد طبعها (A4، إيصال 80مم أو 58مم) أو صدّرها PDF. زر الشاحنة الأخضر يطبع وصل التسليم (Bon de livraison) بدون أسعار للعميل. العمليات الملغاة تبقى في السجل ولا تُمحى.'
             : "Dans Factures, revoyez chaque vente, réimprimez-la (A4, ticket 80/58mm), exportez en PDF, ou imprimez un Bon de livraison sans prix (bouton camion). Les annulations restent dans l'historique."),
      ('6', ar ? 'النقدية والخزائن' : 'Trésorerie',
          ar ? 'صفحة «الصندوق» تدير خزائن متعددة: نقدية، حساب بنكي، خزينة احتياطية. افتح يومك بمبلغ افتتاحي، حول بين الخزائن، سجّل الشيكات المستلمة والصادرة بتواريخ استحقاقها، وسلف العمال مع تسويتها. الرصيد «المتوقع» محسوب دائماً من الحركات الحقيقية حتى تطابقه مع العدّ الفعلي عند الإغلاق.'
             : "La page Caisse gère plusieurs coffres : espèces, banque, réserve. Ouvrez la journée, transférez entre coffres, enregistrez chèques reçus/émis avec échéance et avances salariales. Le solde « attendu » est toujours recalculé depuis les mouvements réels."),
      ('7', ar ? 'تقارير وأرباح' : 'Rapports & bénéfices',
          ar ? 'صفحة «التقارير» تحتوي ربحية كل منتج (هوية أكثر منتجاتك ربحاً، ومثلها الخاسرة)، توقّع مبيعات 30 يوماً (مع تنبيه أنه تقدير)، المبيعات والمصاريف والأرباح حسب الفترة، ومطابقة الأسبوعية/الشهرية. تُصدَّر كلها PDF أو CSV.'
             : "La page Rapports montre la rentabilité par produit, une prévision de ventes 30 jours (indicative), les ventes, dépenses et bénéfices par période, et se compare semaine/mois. Export PDF ou CSV."),
      ('8', ar ? 'الأمان والمستخدمون' : 'Sécurité & utilisateurs',
          ar ? 'من «الإعدادات» أنشئ حسابات موظفين برمز PIN: مدير (كل شيء)، بائع (نقطة البيع والفواتير فقط ولا يرى الأرباح)، محاسب، ومسؤول مخزون. كل عملية تُسجَّل باسم فاعلها في سجل التدقيق، ويمكن دائماً الترجع إليه.'
             : "Dans Paramètres, créez des comptes PIN : gérant (tout), vendeur (POS + factures, sans voir les bénéfices), comptable, responsable stock. Chaque action est signée par son auteur dans le journal d'audit."),
      ('9', ar ? 'النسخ الاحتياطي وإعادة البيع' : 'Sauvegardes',
          ar ? 'فعّل النسخ الاحتياطي التلقائي وأجرِ نسخاً يدوياً بضغطة زر. زر «حذف كل البيانات» يمسح البرنامج بالكامل بعنوان بيعه لشخص آخر (مع نسخة أخيرة اختيارية وإعادة تشغيل معالج التهيئة).'
             : "Activez la sauvegarde automatique et créez des copies manuelles. Le bouton « Tout effacer » vide totalement le programme avant de le revendre (dernière copie optionnelle + assistant de reconfiguration)."),
    ];
  }

  // -------------------------------------------------------------- health tab --
  Widget _health() {
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('health.title'), subtitle: tr('users.roleHint')),
        Row(children: [
          AppButton(
            label: healthRunning ? tr('health.running') : tr('health.run'),
            icon: Icons.health_and_safety_rounded,
            onPressed: healthRunning ? null : _runHealth,
          ),
        ]),
        const SizedBox(height: 14),
        if (health.isEmpty && healthError == null)
          Text(tr('health.runFirst'), style: const TextStyle(fontSize: 12.5, color: C.textSecondary)),
        if (healthError != null) ErrorStateX(message: healthError!, onRetry: _runHealth),
        ...health.map(_healthRow),
      ]),
    );
  }

  Widget _healthRow(HealthResult r) {
    final ok = r.ok;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ok ? C.success.withValues(alpha: .06) : C.warning.withValues(alpha: .07),
          border: Border.all(color: (ok ? C.success : C.warning).withValues(alpha: .45)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              size: 19, color: ok ? C.success : C.warning),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(r.detail, style: const TextStyle(fontSize: 12, color: C.textSecondary, height: 1.5)),
          ])),
        ]),
      ),
    );
  }

  Future<void> _runHealth() async {
    setState(() { healthRunning = true; healthError = null; });
    try {
      final db = AppDatabase.instance.db;
      final results = <HealthResult>[];

      final integrity = (await db.rawQuery('PRAGMA integrity_check')).first.values.first as String;
      results.add(HealthResult(
        title: tr('health.integrity'),
        detail: integrity == 'ok' ? tr('health.ok') : integrity,
        ok: integrity == 'ok',
      ));

      final fk = await db.rawQuery('PRAGMA foreign_key_check');
      results.add(HealthResult(
        title: tr('health.fk'),
        detail: fk.isEmpty ? tr('health.noIssues') : '${fk.length} row(s)',
        ok: fk.isEmpty,
      ));

      final mismatches = await db.rawQuery('''
        SELECT p.name_ar, p.name_fr, p.stock_qty,
               COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.qty ELSE -sm.qty END), 0) AS moves
        FROM products p LEFT JOIN stock_movements sm ON sm.product_id = p.id
        GROUP BY p.id
        HAVING p.stock_qty != COALESCE(SUM(CASE WHEN sm.type = 'in' THEN sm.qty ELSE -sm.qty END), 0)
        LIMIT 20
      ''');
      final diffDetail = mismatches.take(5).map((r) {
        final ar = gIsArabic;
        final n = ar
            ? ((r['name_ar'] as String? ?? '').isNotEmpty ? (r['name_ar'] as String) : (r['name_fr'] as String? ?? '?'))
            : ((r['name_fr'] as String? ?? '').isNotEmpty ? (r['name_fr'] as String? ?? '?') : '?');
        return '$n (${r['stock_qty']} vs ${r['moves']})';
      }).join(' · ');
      results.add(HealthResult(
        title: tr('health.stockMismatch'),
        detail: mismatches.isEmpty ? tr('health.noIssues') : '${tr('health.diffs')}: $diffDetail',
        ok: mismatches.isEmpty,
      ));

      if (!mounted) return;
      setState(() { health = results; healthRunning = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { healthError = '$e'; healthRunning = false; });
    }
  }

  // ------------------------------------------------------------ assistant tab --
  Widget _assistant() {
    final questions = {1: tr('assist.q1'), 2: tr('assist.q2'), 3: tr('assist.q3'), 4: tr('assist.q4'), 5: tr('assist.q5')};
    return HoverCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FormHeader(title: tr('assist.title'), subtitle: tr('assist.ask')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in questions.entries)
            ChoiceChip(
              label: Text(e.value, style: TextStyle(fontSize: 12, color: assistQuestion == e.key ? Colors.white : C.textPrimary)),
              selected: assistQuestion == e.key,
              selectedColor: C.primary,
              backgroundColor: C.bg,
              side: const BorderSide(color: C.border),
              labelPadding: const EdgeInsets.symmetric(horizontal: 10),
              showCheckmark: false,
              onSelected: (_) => _ask(e.key),
            ),
        ]),
        const SizedBox(height: 16),
        if (assistLoading)
          const Center(child: Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator()))
        else if (assistAnswer.isEmpty)
          Text(tr('search.noResults').replaceFirst('أ', ''), style: const TextStyle(fontSize: 12, color: C.textSecondary))
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.primary.withValues(alpha: .05),
              border: Border.all(color: C.primary.withValues(alpha: .3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(assistAnswer, style: const TextStyle(fontSize: 13, height: 1.6, color: C.textPrimary)),
          ),
      ]),
    );
  }

  Future<void> _ask(int q) async {
    final st = context.read<AppState>();
    setState(() { assistQuestion = q; assistLoading = true; });
    String answer;
    try {
      answer = await _answer(st, q);
    } catch (e) {
      answer = '$e';
    }
    if (!mounted) return;
    setState(() { assistAnswer = answer; assistLoading = false; });
  }

  Future<String> _answer(AppState st, int q) async {
    final now = DateTime.now();
    switch (q) {
      case 1:
        final top = await st.analytics.topProducts();
        if (top.isEmpty) return tr('health.noIssues');
        return [for (final e in top.take(5)) '• ${e.$1} × ${e.$2}'].join('\n');
      case 2:
        final d = await st.people.totalCustomerDebt();
        return '${tr('assist.q2')} → ${Money.fmt(d)}';
      case 3:
        final monthStart = DateTime(now.year, now.month, 1);
        final gross = await st.analytics.grossProfitC(Dates.iso(monthStart), Dates.iso(now));
        final net = await st.analytics.netProfitC(Dates.iso(monthStart), Dates.iso(now));
        return '${tr('kpi.grossProfit')}: ${Money.fmt(gross)}\n${tr('kpi.netProfit')}: ${Money.fmt(net)}';
      case 4:
        final rows = await st.analytics.stockAssist();
        final soon = <String>[];
        for (final r in rows) {
          final sold30 = (r['sold30'] as int?) ?? 0;
          final stock = (r['stock'] as int?) ?? 0;
          if (sold30 <= 0 || stock <= 0) continue;
          if (stock / (sold30 / 30.0) <= 14) {
            soon.add('• ${(r['name_fr'] as String? ?? '?')} ($stock)');
          }
        }
        return soon.isEmpty ? tr('health.noIssues') : soon.join('\n');
      case 5:
        final dayStart = DateTime(now.year, now.month, now.day);
        final from = Dates.iso(dayStart), to = Dates.iso(now);
        final sum = await st.analytics.salesSum(from, to);
        final count = await st.analytics.salesCount(from, to);
        final exp = await st.analytics.expensesC(from, to);
        return '${tr('kpi.revenue')}: ${Money.fmt(sum)} · ${tr('nav.overview')}: $count\n${tr('kpi.expenses')}: ${Money.fmt(exp)}';
    }
    return '';
  }
}

class HealthResult {
  const HealthResult({required this.title, required this.detail, required this.ok});
  final String title, detail;
  final bool ok;
}
