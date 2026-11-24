import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dz_business_pro/app/app.dart';
import 'package:dz_business_pro/app/state.dart';
import 'package:dz_business_pro/core/ui.dart';
import 'package:dz_business_pro/data/database/app_database.dart';
import 'package:dz_business_pro/data/models/models.dart';
import 'package:dz_business_pro/features/pos/pos_page.dart';
import 'package:dz_business_pro/features/products/products_page.dart';

/// End-to-end interaction test driving the REAL root widget with a real
/// (temp-file) SQLite database: sidebar navigation, buttons, dialogs, text
/// fields and the POS cart—proving hit-testing works everywhere.
void main() {
  setUpAll(() {
    if (const String.fromEnvironment('OVERFLOW_DUMP', defaultValue: 'false') == 'true') {
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        prev!(d);
        debugDumpRenderTree();
      };
    }
    sqfliteFfiInit();
    // No-isolate so sqlite futures complete under the test FakeAsync clock.
    databaseFactory = createDatabaseFactoryFfi(
      ffiInit: () => open.overrideFor(
          OperatingSystem.linux, () => ffi.DynamicLibrary.open('libsqlite3.so.0')),
      noIsolate: true,
    );
  });

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dzbp_ui');
    if (AppDatabase.instance.isOpen) await AppDatabase.instance.close();
    await AppDatabase.instance.open('${tmp.path}/ui.db');
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    tmp.deleteSync(recursive: true);
  });

  testWidgets('real app: navigate, create product, POS cart, checkout dialog',
      (tester) async {
    final st = AppState();
    st.bootstrapFuture = Future.value();
    st.onboardingDone = true;
    st.profile = BusinessProfile(name: 'Test SARL', language: 'fr');

    tester.view.physicalSize = const ui.Size(1600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(DzBusinessApp(state: st));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Dashboard finished loading (no endless spinner).
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Sidebar navigation to Products.
    await tester.tap(find.text('Produits').first);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is AppButton && w.label == 'Nouveau produit'), findsWidgets);

    // Open the product editor dialog.
    await tester.tap(find.byWidgetPredicate((w) => w is AppButton && w.label == 'Nouveau produit').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductEditor), findsOneWidget);

    // Text fields exist, are hit-testable and accept input (Material present).
    expect(find.byType(TextFormField), findsWidgets);
    await tester.enterText(find.byType(TextFormField).first, 'Stylo');
    await tester.pumpAndSettle();

    // Save.
    final saveBtn = find.byWidgetPredicate(
        (w) => w is AppButton && w.label == 'Enregistrer');
    expect(saveBtn, findsOneWidget);
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    expect(find.text('Stylo'), findsWidgets);

    // Sidebar navigation to POS.
    await tester.tap(find.text('Point de vente').first);
    await tester.pumpAndSettle();
    expect(find.text('Stylo'), findsWidgets);

    // Tap a product card to add it to the cart.
    await tester.tap(find.text('Stylo').first);
    await tester.pumpAndSettle();

    // Open the checkout dialog via the 'Encaisser' button.
    final checkoutBtn = find.byWidgetPredicate(
        (w) => w is AppButton && w.label.startsWith('Encaisser'));
    expect(checkoutBtn, findsOneWidget);
    await tester.tap(checkoutBtn);
    await tester.pumpAndSettle();

    // The checkout dialog builds WITHOUT 'No Material widget found', its
    // fields are editable and the totals row renders.
    expect(find.text('Finaliser la vente'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    await tester.enterText(find.byType(TextFormField).first, '10');
    await tester.pumpAndSettle();

    // Switching payment method with a tap works inside the dialog.
    await tester.tap(find.text('Espèces'));
    await tester.pumpAndSettle();

    // Cancel — returns to POS without saving.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutDialog), findsNothing);
  });

  testWidgets('full sweep: every module renders and supplier save works',
      (tester) async {
    final st = AppState();
    st.bootstrapFuture = Future.value();
    st.onboardingDone = true;
    final lang = const String.fromEnvironment('SWEEP_LANG', defaultValue: 'fr');
    st.profile = BusinessProfile(name: 'Test SARL', language: lang);
    final ar = lang == 'ar';

    tester.view.physicalSize = const ui.Size(1600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(DzBusinessApp(state: st));
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final all = ar
        ? ['لوحة التحكم', 'نقطة البيع', 'المنتجات', 'الفئات والعلامات', 'المخزون', 'الفواتير', 'العملاء', 'الموزّعون', 'المشتريات', 'المصاريف', 'الصندوق', 'التقارير', 'الإعدادات']
        : ['Tableau de bord', 'Point de vente', 'Produits', 'Catégories & marques',
           'Inventaire', 'Factures', 'Clients', 'Fournisseurs', 'Achats',
           'Dépenses', 'Caisse', 'Rapports', 'Paramètres'];
    final mode = const String.fromEnvironment('SWEEP_MODE', defaultValue: 'full');
    final modules = mode.startsWith('only') ? [all[int.parse(mode.substring(4))]] : all;
    for (final label in modules) {
      final nav = find.text(label).first;
      await tester.ensureVisible(nav);
      await tester.pumpAndSettle();
      await tester.tap(nav);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.byWidgetPredicate((w) => w is ErrorWidget), findsNothing,
          reason: '$label rendered an error widget');
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: '$label stuck on a loading spinner');
    }

    // Supplier creation flow (the reported broken button).
    await tester.tap(find.text(ar ? 'الموزّعون' : 'Fournisseurs').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
        (w) => w is AppButton && w.label == (ar ? 'إضافة' : 'Ajouter')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Coca Cola');
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate(
        (w) => w is AppButton && w.label == (ar ? 'حفظ' : 'Enregistrer')).last);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final rows = await AppDatabase.instance.db
        .rawQuery("SELECT COUNT(*) c FROM suppliers WHERE name_fr = 'Coca Cola'");
    expect(rows.first['c'], 1, reason: 'supplier persisted in the database');
    expect(find.text('Coca Cola'), findsWidgets,
        reason: 'supplier saved and visible in the table');

    // Inventory page KPIs render after supplier save (real numbers area).
    await tester.tap(find.text(ar ? 'المخزون' : 'Inventaire').first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text(ar ? 'إدخال مخزون' : 'Entrée de stock'), findsOneWidget);
  });

  /// Pump until the scheduler is idle. Unlike [pumpAndSettle], this tolerates
  /// pending real-async bootstrap I/O and never-times-out animations.
  Future<void> idlePump(WidgetTester tester, {int maxLoops = 40, Duration step = const Duration(milliseconds: 100)}) async {
    for (var i = 0; i < maxLoops; i++) {
      await tester.pump(step);
      if (tester.binding.schedulerPhase == SchedulerPhase.idle &&
          !tester.binding.hasScheduledFrame) {
        break;
      }
    }
  }

  testWidgets('factory reset wipes database and returns to onboarding',
      (tester) async {
    final st = AppState();
    final supportDir = Directory('${tmp.path}/support');
    supportDir.createSync(recursive: true);
    final dbFile = File('${supportDir.path}/dz_business_pro.db');
    // path_provider has no real plugin in widget tests: point the singleton at
    // our temp support directory and run the REAL bootstrap via runAsync (real
    // I/O cannot complete under the test FakeAsync zone).
    st.supportDirOverride = () async => supportDir.path;
    st.databaseFactoryOverride = databaseFactory;
    await AppDatabase.instance.close();
    await tester.runAsync(() => st.bootstrap());
    st.bootstrapFuture = Future.value();

    tester.view.physicalSize = const ui.Size(1600, 900);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(DzBusinessApp(state: st));
    await tester.pump();
    await idlePump(tester);

    // Real bootstrap created a fresh database at the support path.
    expect(dbFile.existsSync(), isTrue);
    // No business profile yet -> onboarding wizard shows.
    expect(find.text('Bienvenue dans DzBusiness Pro'), findsOneWidget);

    // Complete onboarding to reach the main shell (real I/O via runAsync).
    await tester.runAsync(() => st
        .completeOnboarding(BusinessProfile(name: 'Ma SARL', language: 'fr')));
    await idlePump(tester);
    expect(find.text('Tableau de bord'), findsWidgets);

    // Navigate to Parametres.
    final nav = find.text('Param\u00e8tres').first;
    await tester.ensureVisible(nav);
    await idlePump(tester);
    await tester.tap(nav);
    await idlePump(tester, maxLoops: 25);

    // Tap the danger factory-reset button.
    final resetBtn = find
        .byWidgetPredicate(
            (w) => w is AppButton && w.label == 'R\u00e9initialisation usine')
        .first;
    await tester.ensureVisible(resetBtn);
    await idlePump(tester);
    await tester.tap(resetBtn);
    await idlePump(tester, maxLoops: 12);

    // First confirmation (danger): confirm with Supprimer.
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find
        .byWidgetPredicate((w) => w is AppButton && w.label == 'Supprimer')
        .last);
    await idlePump(tester, maxLoops: 12);

    // Backup ask dialog: Annuler = proceed WITHOUT backup.
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Annuler').last);
    await idlePump(tester, maxLoops: 12);

    // factoryReset recreated a fresh, empty database and the root FutureBuilder
    // re-ran bootstrap on rebuild: the onboarding wizard is back.
    // The app returned to the onboarding wizard, on a clean database.
    expect(find.text('Bienvenue dans DzBusiness Pro'), findsOneWidget,
        reason: 'app returns to the onboarding wizard after reset');
    final prof = await AppDatabase.instance.db
        .rawQuery('SELECT COUNT(*) c FROM business_profile');
    expect(prof.first['c'], 0, reason: 'business profile wiped from the fresh database');
  });
}
