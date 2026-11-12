import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:free_music_player/models/song_record.dart';
import 'package:free_music_player/services/database_key_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Encrypted SQLite storage for the song library and user playlists.
class DatabaseService {
  static const String _databaseName = 'cumbionsito.db';
  static const int _databaseVersion = 1;

  static const String _pathsTable = 'PATHS';
  static const String _songsTable = 'SONGS';
  static const String _playlistsTable = 'PLAYLISTS';
  static const String _playlistSongsTable = 'PLAYLIST_SONGS';

  /// Columns for list display: everything except the full-size artwork.
  static const List<String> _listColumns = [
    'id', 'title', 'author', 'album', 'path',
    'folder_locations', 'playlists', 'thumbnail_small',
  ];

  final DatabaseKeyService _keyService;
  Future<Database>? _database;

  DatabaseService([DatabaseKeyService? keyService])
      : _keyService = keyService ?? DatabaseKeyService();

  /// Opens the database once; concurrent callers share the same connection.
  Future<Database> _getDb() => _database ??= _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _databaseName);
    final password = await _keyService.getOrCreateKey();
    Future<Database> open() => openDatabase(
          path,
          password: password,
          version: _databaseVersion,
          onCreate: _onCreate,
        );
    try {
      return await open();
    } on DatabaseException catch (error) {
      // The key is lost when the database file outlives it (for example a
      // file copied from another phone). The library is rebuilt by the next
      // folder scan; only user playlists can't be recovered.
      debugPrint('Library database unreadable, recreating it: $error');
      await deleteDatabase(path);
      return open();
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_pathsTable (
        id             INTEGER PRIMARY KEY,
        playlistspath  TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $_songsTable (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        title            TEXT    NOT NULL,
        author           TEXT    NOT NULL,
        album            TEXT,
        path             TEXT    NOT NULL UNIQUE,
        folder_locations TEXT    NOT NULL DEFAULT '[]',
        playlists        TEXT,
        thumbnail_data   BLOB,
        thumbnail_small  BLOB
      )
    ''');
    await db.execute('''
      CREATE TABLE $_playlistsTable (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE $_playlistSongsTable (
        playlist_id  INTEGER NOT NULL REFERENCES $_playlistsTable(id) ON DELETE CASCADE,
        song_path    TEXT    NOT NULL REFERENCES $_songsTable(path)   ON DELETE CASCADE,
        position     INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (playlist_id, song_path)
      )
    ''');
  }

  SongRecord _listRecord(Map<String, Object?> row) => SongRecord(
        id: row['id'] as int?,
        title: row['title'] as String,
        author: row['author'] as String,
        album: row['album'] as String?,
        path: row['path'] as String,
        folderLocations: row['folder_locations'] != null
            ? List<String>.from(jsonDecode(row['folder_locations'] as String))
            : [],
        playlists: row['playlists'] != null
            ? List<String>.from(jsonDecode(row['playlists'] as String))
            : null,
        thumbnailSmall: row['thumbnail_small'] as Uint8List?,
      );

  // ── PATHS ─────────────────────────────────────────────────────────────────

  Future<void> storeMainFolderPath(String folderPath) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(_pathsTable);
      await txn.insert(_pathsTable, {'playlistspath': folderPath});
    });
  }

  Future<String?> getMainFolderPath() async {
    final db = await _getDb();
    final rows = await db.query(_pathsTable, limit: 1);
    return rows.isEmpty ? null : rows.first['playlistspath'] as String?;
  }

  // ── SONGS ─────────────────────────────────────────────────────────────────

  Future<void> upsertSongs(List<SongRecord> records) async {
    if (records.isEmpty) return;
    final db = await _getDb();
    final batch = db.batch();
    for (final record in records) {
      batch.insert(_songsTable, record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Full-size artwork for the song page, or the thumbnail when there is none.
  Future<Uint8List?> getFullArtwork(String path) async {
    final db = await _getDb();
    final rows = await db.query(_songsTable,
        columns: ['thumbnail_data', 'thumbnail_small'],
        where: 'path = ?',
        whereArgs: [path],
        limit: 1);
    if (rows.isEmpty) return null;
    return (rows.first['thumbnail_data'] ?? rows.first['thumbnail_small'])
        as Uint8List?;
  }

  /// Every song, without full-size artwork.
  Future<List<SongRecord>> getAllSongs() async {
    final db = await _getDb();
    final rows = await db.query(_songsTable, columns: _listColumns);
    return rows.map(_listRecord).toList();
  }

  Future<Set<String>> getAllIndexedPaths() async {
    final db = await _getDb();
    final rows = await db.query(_songsTable, columns: ['path']);
    return rows.map((r) => r['path'] as String).toSet();
  }

  /// Number of songs per folder, from a single query.
  Future<Map<String, int>> getSongCountsByFolder() async {
    final counts = <String, int>{};
    for (final path in await getAllIndexedPaths()) {
      final folder = p.dirname(path);
      counts[folder] = (counts[folder] ?? 0) + 1;
    }
    return counts;
  }

  /// Removes songs and their playlist entries. sqflite doesn't enforce foreign
  /// keys by default, so playlist rows are deleted explicitly.
  Future<void> deleteSongsByPaths(Iterable<String> paths) async {
    final list = paths.toList();
    if (list.isEmpty) return;
    final db = await _getDb();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final path in list) {
        batch.delete(_playlistSongsTable,
            where: 'song_path = ?', whereArgs: [path]);
        batch.delete(_songsTable, where: 'path = ?', whereArgs: [path]);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteSongByPath(String path) => deleteSongsByPaths([path]);

  /// Songs whose folder_locations contains [folderPath], without full artwork.
  Future<List<SongRecord>> getSongsForFolder(String folderPath) async {
    final db = await _getDb();
    final escapedPath = jsonEncode(folderPath);
    final rows = await db.query(
      _songsTable,
      columns: _listColumns,
      where: 'folder_locations LIKE ?',
      whereArgs: ['%$escapedPath%'],
    );
    // LIKE treats "_" and "%" in folder names as wildcards, so confirm the match.
    return rows
        .map(_listRecord)
        .where((record) => record.folderLocations.contains(folderPath))
        .toList();
  }

  // ── PLAYLISTS ─────────────────────────────────────────────────────────────

  /// Creates a playlist and returns its id, or 0 if the name already exists.
  Future<int> createPlaylist(String name) async {
    final db = await _getDb();
    return db.insert(_playlistsTable, {'name': name},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> deletePlaylist(int id) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(_playlistSongsTable,
          where: 'playlist_id = ?', whereArgs: [id]);
      await txn.delete(_playlistsTable, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getAllPlaylists() async {
    final db = await _getDb();
    return db.query(_playlistsTable, orderBy: 'name COLLATE NOCASE ASC');
  }

  /// Adds a song to a playlist. Does nothing if it's already there.
  Future<void> addSongToPlaylist(int playlistId, String songPath) async {
    final db = await _getDb();
    await db.rawInsert('''
      INSERT OR IGNORE INTO $_playlistSongsTable (playlist_id, song_path, position)
      SELECT ?, ?, COALESCE(MAX(position), -1) + 1
      FROM $_playlistSongsTable WHERE playlist_id = ?
    ''', [playlistId, songPath, playlistId]);
  }

  Future<void> removeSongFromPlaylist(int playlistId, String songPath) async {
    final db = await _getDb();
    await db.delete(_playlistSongsTable,
        where: 'playlist_id = ? AND song_path = ?',
        whereArgs: [playlistId, songPath]);
  }

  /// Songs in a playlist, without full artwork.
  Future<List<SongRecord>> getSongsForPlaylist(int playlistId) async {
    final db = await _getDb();
    final columns = _listColumns.map((c) => 's.$c').join(', ');
    final rows = await db.rawQuery('''
      SELECT $columns
      FROM $_songsTable s
      INNER JOIN $_playlistSongsTable ps ON ps.song_path = s.path
      WHERE ps.playlist_id = ?
      ORDER BY ps.position ASC
    ''', [playlistId]);
    return rows.map(_listRecord).toList();
  }

  Future<Set<String>> getPathsInPlaylist(int playlistId) async {
    final db = await _getDb();
    final rows = await db.query(_playlistSongsTable,
        columns: ['song_path'],
        where: 'playlist_id = ?',
        whereArgs: [playlistId]);
    return rows.map((r) => r['song_path'] as String).toSet();
  }
}
