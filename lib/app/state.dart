import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/database/app_database.dart';
import '../data/repositories/repositories.dart';
import '../core/money.dart';
import '../data/models/models.dart';

/// Central application state: owns the database, repositories and the loaded
/// business profile. Feature pages watch this notifier for changes.
class AppState extends ChangeNotifier {
  final AppDatabase database = AppDatabase.instance;

  late final SettingsRepo settings = SettingsRepo(database);
  late final CatalogRepo catalog = CatalogRepo(database);
  late final InventoryRepo inventory = InventoryRepo(database);
  late final PeopleRepo people = PeopleRepo(database, inventory);
  late final SalesRepo sales = SalesRepo(database, inventory, settings);
  late final ReturnsRepo returns = ReturnsRepo(database, inventory, settings);
  late final PurchasesRepo purchases = PurchasesRepo(database, inventory, settings);
  late final ExpensesRepo expenses = ExpensesRepo(database);
  late final CashRepo cash = CashRepo(database);
  late final AnalyticsRepo analytics = AnalyticsRepo(database);

  BusinessProfile profile = BusinessProfile();
  bool onboardingDone = false;
  String dbPath = '';
  Future<void>? bootstrapFuture;

  /// Test hook: when set, [bootstrap] resolves the app-support directory from
  /// here instead of the path_provider plugin (unavailable in widget tests).
  Future<String> Function()? supportDirOverride;

  /// Test hook: when set, [bootstrap] installs this database factory instead
  /// of the isolate-based default (which never completes in widget tests).
  DatabaseFactory? databaseFactoryOverride;

  /// One-shot init future used by the root widget.
  Future<void> get bootstrapDone => bootstrapFuture ??= bootstrap();

  Future<void> bootstrap() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryOverride ?? databaseFactoryFfi;
    final dirPath = supportDirOverride != null
        ? await supportDirOverride!()
        : (await getApplicationSupportDirectory()).path;
    dbPath = p.join(dirPath, 'dz_business_pro.db');
    await database.open(dbPath);
    onboardingDone = await settings.hasBusinessProfile();
    if (onboardingDone) {
      profile = await settings.loadProfile();
    }
  }

  Future<void> completeOnboarding(BusinessProfile p) async {
    await settings.saveProfile(p);
    await settings.set('onboarded_at', Dates.iso(DateTime.now()));
    onboardingDone = true;
    profile = p;
    notifyListeners();
    await settings.audit('onboarding_complete', 'business_profile', 1, p.name);
  }

  Future<void> saveProfile(BusinessProfile p) async {
    await settings.saveProfile(p);
    profile = p;
    notifyListeners();
    await settings.audit('settings_update', 'business_profile', 1, p.name);
  }

  /// Factory reset: wipes ALL business data (for handing the machine to a
  /// new owner). Every table is truncated inside one transaction on the open
  /// connection, audit trail and backups included, then the app returns to
  /// the onboarding wizard on a clean database. The old bootstrap future is
  /// discarded so the root FutureBuilder re-runs [bootstrap] on rebuild.
  Future<void> factoryReset() async {
    final db = database.db;
    await db.execute('PRAGMA foreign_keys = OFF');
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' AND name != 'android_metadata'");
    await db.transaction((txn) async {
      for (final r in tables) {
        final name = r['name'] as String;
        await txn.execute('DELETE FROM "$name"');
      }
    });
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('VACUUM');

    final backups = Directory(p.join(p.dirname(dbPath), 'backups'));
    if (backups.existsSync()) backups.deleteSync(recursive: true);

    bootstrapFuture = null;
    onboardingDone = false;
    profile = BusinessProfile();
    notifyListeners();
  }

  /// Re-runs [bootstrap] on the next root rebuild (after a bootstrap error).
  void retryBootstrap() {
    bootstrapFuture = null;
    notifyListeners();
  }

  /// Emits a change after any repository write so all watching pages refresh.
  void changed() => notifyListeners();

  void reloadFromDb() {
    // profile hot-reload helper (used after restore)
    () async {
      onboardingDone = await settings.hasBusinessProfile();
      if (onboardingDone) profile = await settings.loadProfile();
      notifyListeners();
    }();
  }
}
