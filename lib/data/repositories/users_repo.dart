import 'dart:math';
import '../../core/hash.dart';
import '../../core/money.dart' show Dates;
import '../database/app_database.dart';
import 'repositories.dart' show Audit;

/// Local users, roles and PIN authentication.
///
/// Roles: manager (everything), seller (POS + invoices),
/// accountant (reports + debts), stock (products + inventory + purchases).
class UsersRepo {
  UsersRepo(this.db);
  final AppDatabase db;

  static String hashPin(String pin, String salt) =>
      Sha256.hashString('$salt:$pin');

  static String randomSalt() {
    final r = Random.secure();
    return [
      for (var i = 0; i < 8; i++)
        r.nextInt(256).toRadixString(16).padLeft(2, '0')
    ].join();
  }

  Future<List<User>> list() async {
    final rows = await db.db.query('users', orderBy: 'id ASC');
    return rows.map(User.fromRow).toList();
  }

  Future<User?> byId(int id) async {
    final rows = await db.db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : User.fromRow(rows.first);
  }

  Future<int> create({required String username, required String pin, required String role}) async {
    final salt = randomSalt();
    return db.db.insert('users', {
      'username': username.trim(),
      'password_hash': hashPin(pin, salt),
      'salt': salt,
      'role': role,
      'active': 1,
      'created_at': Dates.iso(DateTime.now()),
    });
  }

  Future<void> updateRole(int id, String role) =>
      db.db.update('users', {'role': role}, where: 'id = ?', whereArgs: [id]);

  Future<void> setActive(int id, bool active) =>
      db.db.update('users', {'active': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);

  Future<void> delete(int id) => db.db.delete('users', where: 'id = ?', whereArgs: [id]);

  Future<void> changePin(int id, String pin) async {
    final salt = randomSalt();
    await db.db.update('users', {
      'password_hash': hashPin(pin, salt), 'salt': salt,
    }, where: 'id = ?', whereArgs: [id]);
  }

  /// Verifies [pin] for [username]; null when credentials are invalid.
  /// Failed attempts are written to audit_logs.
  Future<User?> verify(String username, String pin) async {
    final rows = await db.db.query('users',
        where: 'username = ? COLLATE NOCASE AND active = 1',
        whereArgs: [username.trim()], limit: 1);
    final now = Dates.iso(DateTime.now());
    if (rows.isEmpty) {
      await _logFail('unknown user "$username"', now);
      return null;
    }
    final u = User.fromRow(rows.first);
    if (u.passwordHash != hashPin(pin, u.salt)) {
      await _logFail('"${u.username}"', now);
      return null;
    }
    await db.db.insert('audit_logs', {
      'action': 'login_success', 'entity': 'users', 'entity_id': u.id,
      'details': u.username, 'actor': u.username, 'logged_at': now,
    });
    return u;
  }

  Future<void> _logFail(String who, String now) => db.db.insert('audit_logs', {
        'action': 'login_failed', 'entity': 'users', 'details': who,
        'actor': Audit.actor, 'logged_at': now,
      });

  /// Seed helper used by the login bootstrap: creates the manager account
  /// once, from the settings card, so PIN login can be enabled.
  Future<bool> hasUsers() async =>
      ((await db.db.rawQuery('SELECT COUNT(*) c FROM users')).first['c'] as int) > 0;
}

class User {
  User({this.id = 0, this.username = '', this.passwordHash = '', this.salt = '', this.role = 'cashier', this.active = true, this.createdAt = ''});
  int id;
  String username, passwordHash, salt, role, createdAt;
  bool active;

  static User fromRow(Map<String, Object?> r) => User(
        id: r['id'] as int,
        username: r['username'] as String? ?? '',
        passwordHash: r['password_hash'] as String? ?? '',
        salt: r['salt'] as String? ?? '',
        role: r['role'] as String? ?? 'cashier',
        active: (r['active'] as int? ?? 1) == 1,
        createdAt: r['created_at'] as String? ?? '',
      );
}