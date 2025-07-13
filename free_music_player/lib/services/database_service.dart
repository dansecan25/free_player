//import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  final String databaseName = "freeplayer.db";

  final String pathsTableName = "PATHS";

  final String pathsTable = '''
    CREATE TABLE PATHS(
      id INTEGER PRIMARY KEY,
      playlistspath TEXT
    );
  ''';

  Future<Database> initDB() async {
    final dbpath = await getDatabasesPath();
    final path = join(dbpath, databaseName);

    return openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute(pathsTable);
    });
  }

  /// Store or replace the path
  Future<void> storeMainFolderPath(String folderPath) async {
    final Database db = await initDB();

    // Delete existing rows (keep only one)
    await db.delete(pathsTableName);

    // Insert the new path
    await db.insert(
      pathsTableName,
      {'playlistspath': folderPath},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get stored path, or null if none
  Future<String?> getMainFolderPath() async {
    final Database db = await initDB();

    final List<Map<String, dynamic>> result = await db.query(pathsTableName);

    if (result.isNotEmpty) {
      return result.first['playlistspath'] as String?;
    } else {
      return null;
    }
  }
}
