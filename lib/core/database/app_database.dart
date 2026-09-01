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
      version: 18,
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
        parent_scheme_id INTEGER,
        parent_set_id INTEGER,
        description TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (parent_scheme_id) REFERENCES schemes (scheme_id) ON DELETE SET NULL,
        FOREIGN KEY (parent_set_id) REFERENCES sets (set_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_schemes_parent_scheme_id ON schemes(parent_scheme_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_schemes_parent_set_id ON schemes(parent_set_id)',
    );

    await db.execute('''
      CREATE TABLE sets (
        set_id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheme_id INTEGER NOT NULL,
        set_number INTEGER NOT NULL,
        set_label TEXT NOT NULL,
        details TEXT,
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
        work_order_no TEXT,
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
    await _createMiscCategoriesTable(db);
    await _seedDefaultMiscCategories(db);

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
      await db.execute(
        "ALTER TABLE schemes ADD COLUMN category TEXT NOT NULL DEFAULT 'scheme'",
      );
      await db.execute(
        "UPDATE schemes SET category = 'scheme' WHERE category IS NULL OR TRIM(category) = ''",
      );
    }

    if (oldVersion < 7) {
      await db.execute(
        "ALTER TABLE billing_entries ADD COLUMN is_disabled INTEGER NOT NULL DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE billing_entries ADD COLUMN submitted_to_store_date TEXT",
      );
      await db.execute(
        "ALTER TABLE billing_entries ADD COLUMN transferred_to_scheme TEXT",
      );
      await db.execute("ALTER TABLE billing_entries ADD COLUMN remarks TEXT");
      await db.execute(
        "UPDATE billing_entries SET remarks = notes WHERE (remarks IS NULL OR TRIM(remarks) = '') AND notes IS NOT NULL AND TRIM(notes) <> ''",
      );
    }

    if (oldVersion < 8) {
      await db.execute(
        "ALTER TABLE billing_entries ADD COLUMN transfer_date TEXT",
      );
    }

    if (oldVersion < 9) {
      await db.execute("ALTER TABLE sets ADD COLUMN details TEXT");
    }

    if (oldVersion < 10) {
      await db.execute(
        "ALTER TABLE billing_entries ADD COLUMN work_order_no TEXT",
      );
    }

    if (oldVersion < 11) {
      await _addColumnIfMissing(db, 'schemes', 'parent_scheme_id', 'INTEGER');
      await _addColumnIfMissing(
        db,
        'miscellaneous_items',
        'scheme_id',
        'INTEGER',
      );
      await _addColumnIfMissing(
        db,
        'miscellaneous_entries',
        'work_order_no',
        'TEXT',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_schemes_parent_scheme_id ON schemes(parent_scheme_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_miscellaneous_items_scheme_id ON miscellaneous_items(scheme_id)',
      );
    }

    if (oldVersion < 12) {
      await _addColumnIfMissing(db, 'schemes', 'parent_set_id', 'INTEGER');
      await _addColumnIfMissing(db, 'miscellaneous_items', 'set_id', 'INTEGER');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_schemes_parent_set_id ON schemes(parent_set_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_miscellaneous_items_set_id ON miscellaneous_items(set_id)',
      );
    }

    // Repair databases that were already at version 12 before the scheme/set
    // relationship columns were shipped. These checks are intentionally
    // idempotent so partially upgraded databases can recover safely too.
    if (oldVersion < 13) {
      await _addColumnIfMissing(db, 'schemes', 'parent_scheme_id', 'INTEGER');
      await _addColumnIfMissing(db, 'schemes', 'parent_set_id', 'INTEGER');
      await _addColumnIfMissing(
        db,
        'miscellaneous_items',
        'scheme_id',
        'INTEGER',
      );
      await _addColumnIfMissing(db, 'miscellaneous_items', 'set_id', 'INTEGER');
      await _addColumnIfMissing(
        db,
        'miscellaneous_entries',
        'work_order_no',
        'TEXT',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_schemes_parent_scheme_id ON schemes(parent_scheme_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_schemes_parent_set_id ON schemes(parent_set_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_miscellaneous_items_scheme_id ON miscellaneous_items(scheme_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_miscellaneous_items_set_id ON miscellaneous_items(set_id)',
      );
    }

    if (oldVersion < 14) {
      await _addColumnIfMissing(db, 'schemes', 'sort_order', 'INTEGER NOT NULL DEFAULT 0');
      // Backfill: assign sort_order = row number alphabetically so existing schemes have a sensible default
      await db.rawUpdate('''
        UPDATE schemes SET sort_order = (
          SELECT COUNT(*) FROM schemes AS s2
          WHERE s2.scheme_name < schemes.scheme_name
            OR (s2.scheme_name = schemes.scheme_name AND s2.scheme_id < schemes.scheme_id)
        )
      ''');
    }

    if (oldVersion < 15) {
      await _addColumnIfMissing(db, 'miscellaneous_items', 'description', 'TEXT');
      await _addColumnIfMissing(db, 'miscellaneous_items', 'location_type', "TEXT NOT NULL DEFAULT 'scheme'");
      await _addColumnIfMissing(db, 'miscellaneous_items', 'location_name', 'TEXT');
      await _addColumnIfMissing(db, 'miscellaneous_items', 'location_address', 'TEXT');
      await _addColumnIfMissing(db, 'miscellaneous_items', 'location_description', 'TEXT');
    }

    if (oldVersion < 16) {
      await _addColumnIfMissing(db, 'miscellaneous_items', 'date', 'TEXT');
      await _addColumnIfMissing(db, 'miscellaneous_items', 'amount', "REAL NOT NULL DEFAULT 0");
      // Backfill date from created_at, amount from entries sum
      await db.rawUpdate('''
        UPDATE miscellaneous_items SET
          date = created_at,
          amount = COALESCE((
            SELECT SUM(me.amount) FROM miscellaneous_entries me
            WHERE me.item_id = miscellaneous_items.item_id
          ), 0)
        WHERE date IS NULL OR date = ''
      ''');
    }

    if (oldVersion < 17) {
      await _addColumnIfMissing(db, 'miscellaneous_items', 'work_order_no', 'TEXT');
      await _addColumnIfMissing(db, 'miscellaneous_items', 'voucher_no', 'TEXT');
      await _addColumnIfMissing(db, 'miscellaneous_items', 'reg_page_no', 'TEXT');
      await _addColumnIfMissing(db, 'miscellaneous_items', 'notes', 'TEXT');
      await _addColumnIfMissing(db, 'miscellaneous_items', 'category_data', 'TEXT');
    }

    if (oldVersion < 18) {
      await _createMiscCategoriesTable(db);
      await _seedDefaultMiscCategories(db);
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _createMiscCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS misc_categories (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        description TEXT,
        custom_fields TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedDefaultMiscCategories(Database db) async {
    final existing = await db.query('misc_categories', limit: 1);
    if (existing.isNotEmpty) return;
    final now = _nowFormatted();
    const defaults = [
      ('Leakage', 'water_drop_outlined', 0xFFE53935, 'Leakage related issues and repairs'),
      ('Sluice Valves', 'power_outlined', 0xFF1E88E5, 'Sluice valve operations and maintenance'),
      ('Electrical', 'electrical_services_outlined', 0xFFFDD835, 'Electrical equipment and installations'),
      ('Spare Motor', 'settings_outlined', 0xFF43A047, 'Spare motor inventory and tracking'),
      ('Spare Transformer', 'bolt_outlined', 0xFF8E24AA, 'Spare transformer inventory and tracking'),
      ('Emergency Engine / Emergency Light', 'engineering_outlined', 0xFFD81B60, 'Emergency equipment'),
      ('Bleaching Powder', 'science_outlined', 0xFF00ACC1, 'Bleaching powder inventory'),
      ('Other', 'category_outlined', 0xFF6D4C41, 'Other miscellaneous items'),
    ];
    for (int i = 0; i < defaults.length; i++) {
      final (name, icon, color, desc) = defaults[i];
      await db.insert('misc_categories', {
        'name': name,
        'icon_name': icon,
        'color_value': color,
        'description': desc,
        'sort_order': i,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> _createMiscTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS miscellaneous_items (
        item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        scheme_id INTEGER,
        set_id INTEGER,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        date TEXT,
        amount REAL NOT NULL DEFAULT 0,
        work_order_no TEXT,
        voucher_no TEXT,
        reg_page_no TEXT,
        notes TEXT,
        category_data TEXT,
        location_type TEXT NOT NULL DEFAULT 'scheme',
        location_name TEXT,
        location_address TEXT,
        location_description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (scheme_id) REFERENCES schemes (scheme_id) ON DELETE CASCADE,
        FOREIGN KEY (set_id) REFERENCES sets (set_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS miscellaneous_entries (
        entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL,
        serial_no INTEGER NOT NULL,
        entry_date TEXT NOT NULL,
        work_order_no TEXT,
        voucher_no TEXT,
        amount REAL NOT NULL,
        reg_page_no TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES miscellaneous_items (item_id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_miscellaneous_items_scheme_id ON miscellaneous_items(scheme_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_miscellaneous_items_set_id ON miscellaneous_items(set_id)',
    );
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
