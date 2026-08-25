import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tools/clear_useless_items.dart <db_path>');
    exitCode = 64;
    return;
  }


  final dbPath = args.first;
  final dbFile = File(dbPath);
  if (!dbFile.existsSync()) {
    stderr.writeln('Database file not found: $dbPath');
    exitCode = 66;
    return;
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final backupPath = '$dbPath.bak_${DateTime.now().millisecondsSinceEpoch}';
  dbFile.copySync(backupPath);

  final db = await openDatabase(
    dbPath,
    readOnly: false,
    singleInstance: false,
    onConfigure: (database) async {
      await database.execute('PRAGMA foreign_keys = ON');
    },
  );

  try {
    final beforeRows = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM schemes WHERE LOWER(category) = 'useless_item'",
    );
    final before = (beforeRows.first['cnt'] as num?)?.toInt() ?? 0;

    await db.transaction((txn) async {
      await txn.delete(
        'schemes',
        where: "LOWER(category) = ?",
        whereArgs: ['useless_item'],
      );
    });

    final afterRows = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM schemes WHERE LOWER(category) = 'useless_item'",
    );
    final after = (afterRows.first['cnt'] as num?)?.toInt() ?? 0;

    stdout.writeln('Backup created: $backupPath');
    stdout.writeln('Useless-item schemes before: $before');
    stdout.writeln('Useless-item schemes after:  $after');
  } finally {
    await db.close();
  }
}
