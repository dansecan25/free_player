import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:free_music_player/models/song_record.dart';

class DatabaseService {
  static const String _databaseName = "freeplayer.db";
  static const int _databaseVersion = 2;

  // ── Table: PATHS (settings — which root folder the user chose) ───────────
  static const String _pathsTable = 'PATHS';

  // ── Table: SONGS (the core music library) ────────────────────────────────
  static const String _songsTable = 'SONGS';

  // Expose table names so sync service can refer to them without hard-coding.
  String get songsTableName => _songsTable;
  String get pathsTableName => _pathsTable;

  // ── Singleton DB connection ───────────────────────────────────────────────
  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);

    _db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_pathsTable (
        id             INTEGER PRIMARY KEY,
        playlistspath  TEXT
      );
    ''');
    await db.execute(_songsTableDdl);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate from v1 (PATHS-only) to v2 (adds SONGS table)
      await db.execute(_songsTableDdl);
    }
  }

  static const String _songsTableDdl = '''
    CREATE TABLE IF NOT EXISTS SONGS (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      title            TEXT    NOT NULL,
      author           TEXT    NOT NULL,
      album            TEXT,
      path             TEXT    NOT NULL UNIQUE,
      folder_locations TEXT    NOT NULL DEFAULT '[]',
      playlists        TEXT,
      thumbnail_data   BLOB
    );
  ''';

  // ── PATHS helpers ─────────────────────────────────────────────────────────

  /// Store or replace the single root folder path.
  Future<void> storeMainFolderPath(String folderPath) async {
    final db = await _getDb();
    await db.delete(_pathsTable);
    await db.insert(
      _pathsTable,
      {'playlistspath': folderPath},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the stored root folder path, or null if none set.
  Future<String?> getMainFolderPath() async {
    final db = await _getDb();
    final rows = await db.query(_pathsTable);
    if (rows.isNotEmpty) {
      return rows.first['playlistspath'] as String?;
    }
    return null;
  }

  // ── SONGS helpers ─────────────────────────────────────────────────────────

  /// Insert a new song or, if the path already exists, update all columns
  /// except the primary key.
  Future<void> upsertSong(SongRecord record) async {
    final db = await _getDb();
    await db.insert(
      _songsTable,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert many songs in a single transaction (much faster than looping
  /// [upsertSong] for large batches).
  Future<void> upsertSongs(List<SongRecord> records) async {
    if (records.isEmpty) return;
    final db = await _getDb();
    await db.transaction((txn) async {
      for (final r in records) {
        await txn.insert(
          _songsTable,
          r.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Return the row for a specific audio file path, or null if not indexed.
  Future<SongRecord?> getSongByPath(String path) async {
    final db = await _getDb();
    final rows = await db.query(
      _songsTable,
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SongRecord.fromMap(rows.first);
  }

  /// Return all indexed songs.
  Future<List<SongRecord>> getAllSongs() async {
    final db = await _getDb();
    final rows = await db.query(_songsTable);
    return rows.map(SongRecord.fromMap).toList();
  }

  /// Return all paths that are already indexed (cheap — no BLOB columns read).
  Future<Set<String>> getAllIndexedPaths() async {
    final db = await _getDb();
    final rows = await db.query(_songsTable, columns: ['path']);
    return rows.map((r) => r['path'] as String).toSet();
  }

  /// Update just the folder_locations JSON for a song identified by [path].
  Future<void> updateSongFolderLocations(
      String audioPath, List<String> folderLocations) async {
    final db = await _getDb();
    await db.update(
      _songsTable,
      {'folder_locations': jsonEncode(folderLocations)},
      where: 'path = ?',
      whereArgs: [audioPath],
    );
  }

  /// Remove a song row by its audio file path.
  Future<void> deleteSongByPath(String path) async {
    final db = await _getDb();
    await db.delete(_songsTable, where: 'path = ?', whereArgs: [path]);
  }
}
