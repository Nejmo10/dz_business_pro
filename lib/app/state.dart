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

  /// One-shot init future used by the root widget.
  Future<void> get bootstrapDone => bootstrapFuture ??= bootstrap();

  Future<void> bootstrap() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getApplicationSupportDirectory();
    dbPath = p.join(dir.path, 'dz_business_pro.db');
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
