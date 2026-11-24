import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
}
