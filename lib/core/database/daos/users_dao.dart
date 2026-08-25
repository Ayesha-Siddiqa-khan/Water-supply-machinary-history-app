import '../app_database.dart';

class UsersDao {
  final _dbProvider = AppDatabase.instance;

  Future<void> ensureDefaultUser() async {
    final db = await _dbProvider.database;
    final users = await db.query('users', where: 'username = ?', whereArgs: ['admin'], limit: 1);

    if (users.isEmpty) {
      final now = DateTime.now();
      final createdAt =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await db.insert('users', {
        'username': 'admin',
        'password': 'admin123',
        'full_name': 'Administrator',
        'created_at': createdAt,
      });
    }
  }

  Future<bool> validateCredentials(String username, String password) async {
    final db = await _dbProvider.database;
    final rows = await db.query(
      'users',
      where: 'LOWER(username) = LOWER(?) AND password = ?',
      whereArgs: [username.trim(), password],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  Future<bool> changePassword({
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await _dbProvider.database;

    final validUser = await db.query(
      'users',
      where: 'LOWER(username) = LOWER(?) AND password = ?',
      whereArgs: [username.trim(), currentPassword],
      limit: 1,
    );

    if (validUser.isEmpty) {
      return false;
    }

    await db.update(
      'users',
      {'password': newPassword},
      where: 'LOWER(username) = LOWER(?)',
      whereArgs: [username.trim()],
    );

    return true;
  }
}
