import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('city_water_works.db');
    return _database!;
  }

  Future<String> get databasePath async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'city_water_works.db');
  }

  Future<Database> _initDB(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, fileName);

    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE schemes (
        scheme_id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheme_name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'scheme',
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sets (
        set_id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheme_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        set_label TEXT NOT NULL,
        FOREIGN KEY (scheme_id) REFERENCES schemes (scheme_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE machinery (
        machinery_id INTEGER PRIMARY KEY AUTOINCREMENT,
        set_id INTEGER NOT NULL,
        machinery_type TEXT NOT NULL,
        brand TEXT,
        specs TEXT,
        display_label TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (set_id) REFERENCES sets (set_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE billing_entries (
        entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
        machinery_id INTEGER NOT NULL,
        serial_no INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        voucher_no INTEGER,
        amount REAL NOT NULL,
        reg_page_no TEXT,
        is_disabled INTEGER NOT NULL DEFAULT 0,
        submitted_to_store_date TEXT,
        transfer_date TEXT,
        transferred_to_scheme TEXT,
        remarks TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (machinery_id) REFERENCES machinery (machinery_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE machinery_types (
        type_id INTEGER PRIMARY KEY AUTOINCREMENT,
        type_name TEXT NOT NULL UNIQUE,
        attributes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        full_name TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await _createMiscTables(db);

    // Insert default machinery types
    await _insertDefaultTypes(db);
    await _insertDefaultSettings(db);
    await _insertDefaultUser(db);
  }

  Future<void> _insertDefaultTypes(Database db) async {
    final now = _nowFormatted();

    await db.insert('machinery_types', {
      'type_name': 'Motor',
      'attributes':
          '[{"name":"Horsepower","input_type":"dropdown","options":["20HP","25HP","30HP","40HP"],"required":true},{"name":"Brand","input_type":"text","options":[],"required":false},{"name":"Phase","input_type":"dropdown","options":["Single","Three"],"required":false}]',
      'created_at': now,
    });

    await db.insert('machinery_types', {
      'type_name': 'Pump',
      'attributes':
          '[{"name":"Size","input_type":"dropdown","options":["4x5","3x5"],"required":true},{"name":"Type","input_type":"dropdown","options":["Centrifugal","Submersible"],"required":false}]',
      'created_at': now,
    });

    await db.insert('machinery_types', {
      'type_name': 'Transformer',
      'attributes':
          '[{"name":"kVA Rating","input_type":"dropdown","options":["25kVA","50kVA","100kVA","200kVA"],"required":true},{"name":"Brand","input_type":"text","options":[],"required":false}]',
      'created_at': now,
    });

    await db.insert('machinery_types', {
      'type_name': 'Electrical Items',
      'attributes':
          '[{"name":"Item Name","input_type":"dropdown","options":["Cable","Breaker","Switch","Panel"],"required":true},{"name":"Specification","input_type":"text","options":[],"required":false}]',
      'created_at': now,
    });

    await db.insert('machinery_types', {
      'type_name': 'Turbine',
      'attributes':
          '[{"name":"Model","input_type":"text","options":[],"required":false},{"name":"Flow Rate","input_type":"number","options":[],"required":false}]',
      'created_at': now,
    });

    await db.insert('machinery_types', {
      'type_name': 'Miscellaneous',
      'attributes':
          '[{"name":"Item Type","input_type":"dropdown","options":["Leakage","Pipes","Starter","Valves"],"required":true},{"name":"Sub Item","input_type":"dropdown","options":["Main Leakage","Joint Leakage","Service Leakage","GI Pipe","PVC Pipe","HDPE Pipe","Electrical Head","Starter","Starter Relay","Gate Valve","Air Valve","Check Valve"],"required":false},{"name":"Size (Inches)","input_type":"dropdown","options":["3 Inches","4 Inches","5 Inches","6 Inches","8 Inches","9 Inches","12 Inches","15 Inches","18 Inches","24 Inches"],"required":false},{"name":"Starter Type","input_type":"dropdown","options":["Electrical Head","Starter"],"required":false}]',
      'created_at': now,
    });
  }

  Future<void> _insertDefaultSettings(Database db) async {
    final defaults = {
      'theme': 'system',
      'primary_color': '#1E3A5F',
      'currency_symbol': 'PKR',
      'amount_format': 'formatted', // formatted = 1,000; plain = 1000
      'auto_backup': 'off',
      'default_export_format': 'pdf',
      'pdf_paper_size': 'a4',
      'app_language': 'english',
      'remember_me': 'false',
      'logged_in_user': '',
    };
    for (final entry in defaults.entries) {
      await db.insert('app_settings', {'key': entry.key, 'value': entry.value});
    }
  }

  Future<void> _insertDefaultUser(Database db) async {
    final now = _nowFormatted();
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123',
      'full_name': 'Administrator',
      'created_at': now,
    });
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          user_id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          full_name TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      final existingUsers = await db.query('users', limit: 1);
      if (existingUsers.isEmpty) {
        await _insertDefaultUser(db);
      }
    }

    if (oldVersion < 3) {
      await db.update(
        'machinery_types',
        {
          'attributes':
              '[{"name":"Item Type","input_type":"dropdown","options":["Leakage","Pipes","Starter","Valves"],"required":true},{"name":"Size (Inches)","input_type":"dropdown","options":["3 Inches","4 Inches","5 Inches","6 Inches","8 Inches","9 Inches","12 Inches","15 Inches","18 Inches","24 Inches"],"required":false},{"name":"Starter Type","input_type":"dropdown","options":["Electrical Head","Starter"],"required":false}]',
        },
        where: 'LOWER(type_name) = ?',
        whereArgs: ['miscellaneous'],
      );
    }

    if (oldVersion < 4) {
      await db.update(
        'machinery_types',
        {
          'attributes':
              '[{"name":"Item Type","input_type":"dropdown","options":["Leakage","Pipes","Starter","Valves"],"required":true},{"name":"Sub Item","input_type":"dropdown","options":["Main Leakage","Joint Leakage","Service Leakage","GI Pipe","PVC Pipe","HDPE Pipe","Electrical Head","Starter","Starter Relay","Gate Valve","Air Valve","Check Valve"],"required":false},{"name":"Size (Inches)","input_type":"dropdown","options":["3 Inches","4 Inches","5 Inches","6 Inches","8 Inches","9 Inches","12 Inches","15 Inches","18 Inches","24 Inches"],"required":false},{"name":"Starter Type","input_type":"dropdown","options":["Electrical Head","Starter"],"required":false}]',
        },
        where: 'LOWER(type_name) = ?',
        whereArgs: ['miscellaneous'],
      );
    }

    if (oldVersion < 5) {
      await _createMiscTables(db);
      await _migrateMiscFromSettings(db);
    }

    if (oldVersion < 6) {
      await db.execute("ALTER TABLE schemes ADD COLUMN category TEXT NOT NULL DEFAULT 'scheme'");
      await db.execute("UPDATE schemes SET category = 'scheme' WHERE category IS NULL OR TRIM(category) = ''");
    }

    if (oldVersion < 7) {
      await db.execute("ALTER TABLE billing_entries ADD COLUMN is_disabled INTEGER NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE billing_entries ADD COLUMN submitted_to_store_date TEXT");
      await db.execute("ALTER TABLE billing_entries ADD COLUMN transferred_to_scheme TEXT");
      await db.execute("ALTER TABLE billing_entries ADD COLUMN remarks TEXT");
      await db.execute(
        "UPDATE billing_entries SET remarks = notes WHERE (remarks IS NULL OR TRIM(remarks) = '') AND notes IS NOT NULL AND TRIM(notes) <> ''",
      );
    }

    if (oldVersion < 8) {
      await db.execute("ALTER TABLE billing_entries ADD COLUMN transfer_date TEXT");
    }
  }

  Future<void> _createMiscTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS miscellaneous_items (
        item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS miscellaneous_entries (
        entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL,
        serial_no INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        voucher_no TEXT,
        amount REAL NOT NULL,
        reg_page_no TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES miscellaneous_items (item_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _migrateMiscFromSettings(Database db) async {
    final existing = await db.query('miscellaneous_items', limit: 1);
    if (existing.isNotEmpty) return;

    final settings = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['misc_records_json'],
      limit: 1,
    );
    if (settings.isEmpty) return;

    final raw = (settings.first['value'] as String?)?.trim();
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      for (final item in decoded.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final now = _nowFormatted();
        final itemId = await db.insert('miscellaneous_items', {
          'title': (map['title'] ?? '').toString(),
          'category': (map['category'] ?? 'Miscellaneous').toString(),
          'created_at': now,
          'updated_at': now,
        });

        final entries = map['entries'];
        if (entries is List) {
          for (int i = 0; i < entries.length; i++) {
            final entry = entries[i];
            if (entry is! Map) continue;
            final e = Map<String, dynamic>.from(entry);
            await db.insert('miscellaneous_entries', {
              'item_id': itemId,
              'serial_no': i + 1,
              'entry_date': (e['entryDate'] ?? '').toString(),
              'voucher_no': e['voucherNo']?.toString(),
              'amount': double.tryParse((e['amount'] ?? 0).toString()) ?? 0,
              'reg_page_no': e['regPageNo']?.toString(),
              'notes': e['notes']?.toString(),
              'created_at': now,
              'updated_at': now,
            });
          }
        }
      }
    } catch (_) {}
  }

  String _nowFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Replace the database with a restored file
  Future<void> replaceDatabase(String sourcePath) async {
    await closeDatabase();
    final dbPath = await databasePath;
    // Copy source to current DB path
    final sourceDb = await openDatabase(sourcePath, readOnly: true);
    await sourceDb.close();

    // Use raw file copy
    await deleteDatabase(dbPath);
    // Re-open from restored
    _database = await openDatabase(
      sourcePath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }
}
