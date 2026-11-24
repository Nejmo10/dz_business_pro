import 'dart:io' as dio;
import 'dart:typed_data';

import 'package:bidi/bidi.dart' as bidi;
import 'package:file_selector/file_selector.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../app/l10n.dart';
import '../app/state.dart';
import '../core/fonts/font_assets.dart';
import '../core/money.dart';
import '../data/models/models.dart';


/// Builds and prints invoices (A4) and thermal receipts (80/58mm).
/// Arabic text is visually reordered (Bidi algorithm) and rendered using the
/// embedded Cairo font.
class PrintService {
  PrintService(this.state);
  final AppState state;

  static pw.Font? _font;
  static pw.Font? _bold;

  static Future<void> ensureFonts() async {
    if (_font != null) return;
    _font = pw.Font.ttf(FontRegistrar.cairoRegular());
    _bold = pw.Font.ttf(FontRegistrar.cairoBold());
  }

  static String _fix(String s) {
    if (!RegExp('[\u0590-\u08FF]').hasMatch(s)) return s;
    return bidi.logicalToVisual2(s, <int>[], <int>[]);
  }

  static pw.TextStyle _st({double size = 10, bool bold = false, PdfColor? color}) {
    return pw.TextStyle(
      font: bold ? _bold : _font,
      fontSize: size,
      color: color ?? PdfColor.fromInt(0xFF192338),
    );
  }

  BusinessProfile get profile => state.profile;

  // ---------------------------------------------------------------- A4 invoice
  Future<Uint8List> saleA4(Sale sale, List<SaleItem> items) async {
    await ensureFonts();
    await _cacheCustomers([sale]);
    final doc = pw.Document();
    String t(String k) => _fix(tr(k));
    String money(int c) => _fix(Money.fmt(c, symbol: ' ${profile.currency}'));
    final status = t(sale.status == 'cancelled' ? 'returned' : 'active');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: _font!, bold: _bold!),
      build: (ctx) => [
       pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_fix(profile.name), style: _st(size: 18, bold: true)),
              if (profile.activity.isNotEmpty) pw.Text(_fix(profile.activity), style: _st(size: 9, color: PdfColor.fromInt(0xFF7B879C))),
              pw.SizedBox(height: 3),
              if (profile.address.isNotEmpty) pw.Text(_fix(profile.address), style: _st(size: 9)),
              if (profile.phone.isNotEmpty) pw.Text(_fix('${tr('phone')}: ${profile.phone}'), style: _st(size: 9)),
              if (profile.email.isNotEmpty) pw.Text(profile.email, style: _st(size: 9)),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF3867F4), borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text(t('invoice.of'), style: _st(size: 13, bold: true, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('${t('inv.no')}: ${sale.invoiceNo}', style: _st(size: 10, bold: true)),
              pw.Text(_fix('${t('date')}: ${sale.saleAt}'), style: _st(size: 9)),
              pw.Text('${t('status')}: $status', style: _st(size: 9)),
            ]),
          ]),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE8EDF5)),
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColor.fromInt(0xFFF5F7FC),
            ),
            child: pw.Row(children: [
              pw.Text('${t('customer')}: ',
                  style: _st(size: 10, bold: true)),
              pw.Text(_fix(_customerName(sale.customerId)), style: _st(size: 10)),
            ]),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headerStyle: _st(size: 9.5, bold: true, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF3867F4)),
            cellStyle: _st(size: 9.5),
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE8EDF5), width: .5),
            headers: [t('name'), t('qty'), t('price'), t('discount'), t('total')],
            data: [
              for (final it in items)
                [
                  _fix(_itemName(it)),
                  '${it.qty}',
                  money(it.unitPriceC),
                  money(it.discountC),
                  money(it.totalC),
                ]
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              width: 230,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE8EDF5)),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _totRow(t('subtotal'), sale.subtotalC, money),
                if (sale.discountC > 0) _totRow(t('discount'), -sale.discountC, money),
                if (sale.taxC > 0) _totRow(t('tax'), sale.taxC, money),
                pw.Divider(color: PdfColor.fromInt(0xFFE8EDF5)),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text(t('total'), style: _st(size: 12, bold: true)),
                  pw.Text(money(sale.totalC), style: _st(size: 12, bold: true)),
                ]),
                pw.SizedBox(height: 4),
                _totRow(t('paid'), sale.paidC, money, valueOverride: sale.paidC == sale.totalC ? t('paid') : null),
                pw.SizedBox(height: 2),
                _totRow(t('remaining'), sale.totalC - sale.paidC, money),
                pw.SizedBox(height: 2),
                _totRow(t('method'), 0, money, valueOverrideText: t(sale.paymentMethod)),
              ]),
            ),
          ]),
          pw.Spacer(),
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(_fix('${profile.name} — ${tr('app.title')}'),
                style: _st(size: 8, color: PdfColor.fromInt(0xFF7B879C))),
          ),
          pw.SizedBox(height: 2),
        ])
      ],
    ));
    return doc.save();
  }

  pw.Widget _totRow(String label, int valueC, String Function(int) money, {String? valueOverride, String? valueOverrideText}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: _st(size: 9.5, color: PdfColor.fromInt(0xFF7B879C))),
        if (valueOverrideText != null)
          pw.Text(valueOverrideText, style: _st(size: 9.5, bold: true))
        else
          pw.Text(valueOverride ?? money(valueC), style: _st(size: 9.5)),
      ]),
    );
  }

  String _customerName(int? id) {
    if (id == null) return tr('walkIn');
    final c = _customerCache[id];
    return c?.name(gLocale == 'ar') ?? tr('walkIn');
  }

  final Map<int, Customer?> _customerCache = {};

  Future<void> _cacheCustomers(List<Sale> sales) async {
    for (final s in sales) {
      final id = s.customerId;
      if (id == null || _customerCache.containsKey(id)) continue;
      _customerCache[id] = await state.people.customerById(id);
    }
  }

  String _itemName(SaleItem it) => gLocale == 'ar' ? it.nameAr : it.nameFr;

  // ------------------------------------------------------------ thermal receipt
  Future<Uint8List> receipt80(Sale sale, List<SaleItem> items) =>
      _receipt(sale, items, 80);
  Future<Uint8List> receipt58(Sale sale, List<SaleItem> items) =>
      _receipt(sale, items, 58);

  Future<Uint8List> _receipt(Sale sale, List<SaleItem> items, int mm) async {
    await ensureFonts();
    final doc = pw.Document();
    String t(String k) => _fix(tr(k));
    String money(int c) => _fix(Money.fmt(c, symbol: profile.currency));
    final format = mm == 80 ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      theme: pw.ThemeData.withFont(base: _font!, bold: _bold!),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Text(_fix(profile.name), textAlign: pw.TextAlign.center, style: _st(size: mm/10, bold: true)),
        if (profile.address.isNotEmpty)
          pw.Text(_fix(profile.address), textAlign: pw.TextAlign.center, style: _st(size: 7)),
        pw.SizedBox(height: 2),
        pw.Text('${sale.invoiceNo}   ${sale.saleAt}', textAlign: pw.TextAlign.center, style: _st(size: 7)),
        if (_customerLine(sale).isNotEmpty) ...[
          pw.Text(_fix(_customerLine(sale)), textAlign: pw.TextAlign.center, style: _st(size: 7)),
        ],
        pw.Divider(color: PdfColor.fromInt(0xFF192338)),
        for (final it in items) pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_fix(_itemName(it)), style: _st(size: 8, bold: true)),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('${it.qty} x ${money(it.unitPriceC)}', style: _st(size: 8)),
            pw.Text(money(it.totalC), style: _st(size: 8, bold: true)),
          ]),
        ]),
        pw.Divider(color: PdfColor.fromInt(0xFF192338)),
        _receiptRow(t('subtotal'), sale.subtotalC, money, 8),
        if (sale.discountC > 0) _receiptRow(t('discount'), -sale.discountC, money, 8),
        if (sale.taxC > 0) _receiptRow(t('tax'), sale.taxC, money, 8),
        _receiptRow(t('total'), sale.totalC, money, 10, bold: true),
        _receiptRow(t('paid'), sale.paidC, money, 8),
        _receiptRow(t('remaining'), sale.totalC - sale.paidC, money, 8),
        _receiptRow(t('method'), 0, money, 8, textOverride: t(sale.paymentMethod)),
        pw.SizedBox(height: 8),
        pw.Text(tr('sale.ticket'), textAlign: pw.TextAlign.center, style: _st(size: 7)),
        pw.Text(_fix('${profile.name} — ${tr('app.title')}'), textAlign: pw.TextAlign.center, style: _st(size: 6)),
      ]),
    ));
    return doc.save();
  }

  String _customerLine(Sale sale) {
    final name = _customerName(sale.customerId);
    if (sale.customerId == null || name == tr('walkIn')) return '';
    return '${tr('customer')}: $name';
  }

  pw.Widget _receiptRow(String label, int valueC, String Function(int) money, double size, {bool bold = false, String? textOverride}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: _st(size: size, bold: bold)),
        pw.Text(textOverride ?? money(valueC), style: _st(size: size, bold: bold)),
      ]),
    );
  }

  // ------------------------------------------------------------- purchase A4
  Future<Uint8List> purchaseA4(Purchase p, List<PurchaseItem> items) async {
    await ensureFonts();
    final doc = pw.Document();
    String t(String k) => _fix(tr(k));
    String money(int c) => _fix(Money.fmt(c, symbol: ' ${profile.currency}'));
    final supplierRows = await state.database.db.query('suppliers',
        where: 'id = ?', whereArgs: [p.supplierId], limit: 1);
    final supplier = supplierRows.isEmpty ? null : Supplier.fromRow(supplierRows.first);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: _font!, bold: _bold!),
      build: (ctx) => [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_fix(profile.name), style: _st(size: 16, bold: true)),
              pw.SizedBox(height: 2),
              pw.Text('${t('supplier')}: ${_fix(supplier?.name(gLocale == 'ar') ?? '-')}', style: _st(size: 10)),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF7357E8), borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text(t('purch.new'), style: _st(size: 11, bold: true, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('${t('inv.no')}: ${p.invoiceNo}', style: _st(size: 10, bold: true)),
              pw.Text(_fix('${t('date')}: ${p.purchaseAt}'), style: _st(size: 9)),
            ]),
          ]),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headerStyle: _st(size: 9.5, bold: true, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF7357E8)),
            cellStyle: _st(size: 9.5),
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE8EDF5), width: .5),
            headers: [t('name'), t('qty'), t('cost'), t('total')],
            data: [
              for (final it in items)
                [_fix(gLocale == 'ar' ? it.nameAr : it.nameFr), '${it.qty}', money(it.unitCostC), money(it.totalC)]
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromInt(0xFFE8EDF5)),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Column(children: [
                _totRow(t('subtotal'), p.subtotalC, money),
                if (p.discountC > 0) _totRow(t('discount'), -p.discountC, money),
                if (p.extraCostsC > 0) _totRow(t('purch.extraCosts'), p.extraCostsC, money),
                pw.Divider(color: PdfColor.fromInt(0xFFE8EDF5)),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text(t('total'), style: _st(size: 12, bold: true)),
                  pw.Text(money(p.totalC), style: _st(size: 12, bold: true)),
                ]),
                pw.SizedBox(height: 2),
                _totRow(t('paid'), p.paidC, money),
                _totRow(t('remaining'), p.totalC - p.paidC, money),
              ]),
            ),
          ]),
        ])
      ],
    ));
    return doc.save();
  }

  // ------------------------------------------------------- delivery note (A4)
  /// Bon de livraison: quantities and products only — no prices, no totals.
  Future<Uint8List> deliveryNote(Sale sale, List<SaleItem> items) async {
    await ensureFonts();
    await _cacheCustomers([sale]);
    final doc = pw.Document();
    String t(String k) => _fix(tr(k));
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: _font!, bold: _bold!),
      build: (ctx) => [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_fix(profile.name), style: _st(size: 16, bold: true)),
              if (profile.address.isNotEmpty) pw.Text(_fix(profile.address), style: _st(size: 9)),
              if (profile.phone.isNotEmpty) pw.Text(_fix('${tr('phone')}: ${profile.phone}'), style: _st(size: 9)),
            ])),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF16A879), borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Text(t('bl.title'), style: _st(size: 13, bold: true, color: PdfColors.white)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('${t('inv.no')}: ${sale.invoiceNo}', style: _st(size: 10, bold: true)),
              pw.Text(_fix('${t('date')}: ${sale.saleAt}'), style: _st(size: 9)),
            ]),
          ]),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE8EDF5)),
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColor.fromInt(0xFFF5F7FC),
            ),
            child: pw.Row(children: [
              pw.Text('${t('customer')}: ', style: _st(size: 10, bold: true)),
              pw.Text(_fix(_customerName(sale.customerId)), style: _st(size: 10)),
            ]),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headerStyle: _st(size: 9.5, bold: true, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF16A879)),
            cellStyle: _st(size: 9.5),
            border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE8EDF5), width: .5),
            headers: [t('name'), t('qty'), t('bl.note')],
            data: [
              for (final it in items) [_fix(_itemName(it)), '${it.qty}', ''],
            ],
          ),
          pw.SizedBox(height: 40),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(children: [
              pw.Text(t('bl.signature'), style: _st(size: 9)),
              pw.SizedBox(height: 34),
              pw.Container(width: 150, height: .8, color: PdfColor.fromInt(0xFF7B879C)),
            ]),
            pw.Column(children: [
              pw.Text(t('bl.receiver'), style: _st(size: 9)),
              pw.SizedBox(height: 34),
              pw.Container(width: 150, height: .8, color: PdfColor.fromInt(0xFF7B879C)),
            ]),
          ]),
          pw.Spacer(),
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.only(top: 12),
            child: pw.Text(_fix('${profile.name} — ${tr('app.title')}'),
                style: _st(size: 8, color: PdfColor.fromInt(0xFF7B879C))),
          ),
        ])
      ],
    ));
    return doc.save();
  }

  Future<void> printDeliveryNote(Sale sale, List<SaleItem> items) async {
    await printBytes(await deliveryNote(sale, items));
  }

  // ------------------------------------------------------------------ outputs
  Future<void> printBytes(Uint8List bytes, {PdfPageFormat? format, bool usePrinter = false}) async {
    await ensureFonts();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      format: format ?? PdfPageFormat.a4,
      usePrinterSettings: usePrinter,
    );
  }

  Future<void> printSale(Sale sale, List<SaleItem> items, String format) async {
    switch (format) {
      case '80':
        await printBytes(await receipt80(sale, items), format: PdfPageFormat.roll80, usePrinter: true);
      case '58':
        await printBytes(await receipt58(sale, items), format: PdfPageFormat.roll57, usePrinter: true);
      default:
        await printBytes(await saleA4(sale, items));
    }
  }

  Future<void> printPurchase(Purchase p, List<PurchaseItem> items) async {
    await printBytes(await purchaseA4(p, items));
  }

  /// Exports an A4 sales invoice as a PDF file chosen by the user.
  Future<void> exportInvoice(Sale sale, List<SaleItem> items) async {
    await exportPdf(await saleA4(sale, items), '${sale.invoiceNo}.pdf');
  }

  /// Builds an A4 tabular report PDF and prints it via the layout preview.
  Future<void> reportPdf(String title, String subtitle, List<String> headers, List<List<String>> rows) async {
    await ensureFonts();
    final doc = pw.Document();
    String f(String s) => _fix(s);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: _font!, bold: _bold!),
      build: (ctx) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(f(title), style: _st(size: 16, bold: true, color: PdfColor.fromInt(0xFF3867F4))),
            if (subtitle.isNotEmpty) pw.SizedBox(height: 3),
            if (subtitle.isNotEmpty) pw.Text(f(subtitle), style: _st(size: 9, color: PdfColor.fromInt(0xFF7B879C))),
          ])),
          pw.Text(f(profile.name), style: _st(size: 10, bold: true)),
        ]),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headerStyle: _st(size: 9, bold: true, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF3867F4)),
          cellStyle: _st(size: 9),
          border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE8EDF5), width: .5),
          cellAlignment: pw.Alignment.centerLeft,
          headers: [for (final h in headers) f(h)],
          data: [for (final row in rows) [for (final c in row) f(c)]],
        ),
        pw.SizedBox(height: 10),
        pw.Text('${rows.length}', style: _st(size: 8, color: PdfColor.fromInt(0xFF7B879C))),
      ],
    ));
    await printBytes(await doc.save());
  }

  /// Exports to a user-chosen *.pdf file.
  Future<void> exportPdf(Uint8List bytes, String suggestedName) async {
    final location = await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: [
      const XTypeGroup(label: 'PDF', extensions: ['pdf']),
    ]);
    if (location == null) return;
    await dio.File(location.path).writeAsBytes(bytes);
  }
}
