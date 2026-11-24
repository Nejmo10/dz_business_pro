import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../data/migrations/migrations.dart';

/// The single SQLite entry point of DzBusiness Pro.
///
/// - Foreign keys are enforced.
/// - Schema is versioned; migrations are forward-only and never destroy data.
/// - The database file lives in the OS application-support directory.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  static const int version = 2;

  /// Opens (creating or migrating) the database at [path].
  /// If [path] is the in-memory path, runs entirely in RAM (used by tests).
  Future<Database> open(String path, {String? dbPassword}) async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await openDatabase(
      path,
      version: version,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: _onConfigure,
        onCreate: (db, v) async => Migrations.createAll(db, v),
        onUpgrade: (db, from, to) async => Migrations.migrate(db, from, to),
        onOpen: _onOpen,
      ),
    );
    return _db!;
  }

  /// In-memory database for tests / integrity sandboxing.
  static const String inMemory = 'file::memory:?cache=shared';

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = FULL');
  }

  Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await Migrations.verifyIntegrity(db);
  }

  Database get db {
    final d = _db;
    if (d == null || !d.isOpen) {
      throw StateError('Database not opened');
    }
    return d;
  }

  bool get isOpen => _db != null && _db!.isOpen;

  /// PRAGMA integrity_check — returns true when the database is healthy.
  Future<bool> integrityCheck() async {
    final rows = await _db!.rawQuery('PRAGMA integrity_check');
    for (final row in rows) {
      final v = row.values.first?.toString();
      if (v != null && !v.startsWith('ok')) return false;
    }
    final fk = await _db!.rawQuery('PRAGMA foreign_key_check');
    return fk.isEmpty;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Backs up the DB file at [dbPath] into [targetPath] using the Online
  /// Backup API equivalent: copies with a lock via `VACUUM INTO` (SQLite >=3.27)
  /// which produces a consistent snapshot without blocking.
  static Future<void> backupFile(Database db, String targetPath) async {
    await db.execute('VACUUM INTO ?', [targetPath]);
  }

  /// Backs the live DB up before restoring [backupPath] over [dbPath].
  static String safetyPath(String dbPath) {
    final dir = p.dirname(dbPath);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir, 'safety_before_restore_$stamp.db');
  }
}
