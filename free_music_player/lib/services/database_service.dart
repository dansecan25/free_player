import 'dart:convert';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:free_music_player/models/song_record.dart';

class DatabaseService {
  static const String _databaseName = "freeplayer.db";
  static const int _databaseVersion = 4;

  // ── Table names ───────────────────────────────────────────────────────────
  static const String _pathsTable        = 'PATHS';
  static const String _songsTable        = 'SONGS';
  static const String _playlistsTable    = 'PLAYLISTS';
  static const String _playlistSongsTable = 'PLAYLIST_SONGS';

  String get songsTableName        => _songsTable;
  String get pathsTableName        => _pathsTable;
  String get playlistsTableName    => _playlistsTable;
  String get playlistSongsTableName => _playlistSongsTable;

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
    await db.execute(_playlistsTableDdl);
    await db.execute(_playlistSongsTableDdl);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(_songsTableDdl);
    }
    if (oldVersion < 3) {
      await db.execute(_playlistsTableDdl);
      await db.execute(_playlistSongsTableDdl);
    }
    if (oldVersion < 4) {
      // Add compressed thumbnail column (nullable — filled lazily on next sync)
      await db.execute(
          'ALTER TABLE SONGS ADD COLUMN thumbnail_small BLOB');
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
      thumbnail_data   BLOB,
      thumbnail_small  BLOB
    );
  ''';

  static const String _playlistsTableDdl = '''
    CREATE TABLE IF NOT EXISTS PLAYLISTS (
      id    INTEGER PRIMARY KEY AUTOINCREMENT,
      name  TEXT    NOT NULL UNIQUE
    );
  ''';

  static const String _playlistSongsTableDdl = '''
    CREATE TABLE IF NOT EXISTS PLAYLIST_SONGS (
      playlist_id  INTEGER NOT NULL REFERENCES PLAYLISTS(id) ON DELETE CASCADE,
      song_path    TEXT    NOT NULL REFERENCES SONGS(path)   ON DELETE CASCADE,
      position     INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (playlist_id, song_path)
    );
  ''';

  // ── PATHS helpers ─────────────────────────────────────────────────────────

  Future<void> storeMainFolderPath(String folderPath) async {
    final db = await _getDb();
    await db.delete(_pathsTable);
    await db.insert(
      _pathsTable,
      {'playlistspath': folderPath},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMainFolderPath() async {
    final db = await _getDb();
    final rows = await db.query(_pathsTable);
    if (rows.isNotEmpty) return rows.first['playlistspath'] as String?;
    return null;
  }

  // ── SONGS helpers ─────────────────────────────────────────────────────────

  Future<void> upsertSong(SongRecord record) async {
    final db = await _getDb();
    await db.insert(
      _songsTable,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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

  Future<List<SongRecord>> getAllSongs() async {
    final db = await _getDb();
    final rows = await db.query(_songsTable, orderBy: 'title ASC');
    return rows.map(SongRecord.fromMap).toList();
  }

  Future<Set<String>> getAllIndexedPaths() async {
    final db = await _getDb();
    final rows = await db.query(_songsTable, columns: ['path']);
    return rows.map((r) => r['path'] as String).toSet();
  }

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

  Future<void> deleteSongByPath(String path) async {
    final db = await _getDb();
    await db.delete(_songsTable, where: 'path = ?', whereArgs: [path]);
  }

  /// Return all songs whose folder_locations JSON contains [folderPath].
  /// Single SQL query — replaces N calls to [getSongByPath].
  /// Returns only the columns needed for display (no full thumbnail_data BLOB
  /// unless [includeFullArt] is true) to keep the initial load fast.
  Future<List<SongRecord>> getSongsForFolder(
    String folderPath, {
    bool includeFullArt = false,
  }) async {
    final db = await _getDb();
    // Use JSON fragment search — folder_locations is stored as a JSON array
    // of strings, so any row containing the path as a JSON string value will
    // have a fragment like  ..."<folderPath>"...
    final escapedPath = folderPath.replaceAll('"', '\\"');
    final columns = includeFullArt
        ? null // all columns
        : <String>[
            'id', 'title', 'author', 'album', 'path',
            'folder_locations', 'playlists', 'thumbnail_small',
          ];
    final rows = await db.query(
      _songsTable,
      columns: columns,
      where: "folder_locations LIKE ?",
      whereArgs: ['%"$escapedPath"%'],
      orderBy: 'title ASC',
    );
    return rows.map((r) {
      // When we excluded thumbnail_data, reconstruct SongRecord with null for it
      if (!includeFullArt) {
        return SongRecord(
          id: r['id'] as int?,
          title: r['title'] as String,
          author: r['author'] as String,
          album: r['album'] as String?,
          path: r['path'] as String,
          folderLocations: r['folder_locations'] != null
              ? List<String>.from(jsonDecode(r['folder_locations'] as String))
              : [],
          playlists: r['playlists'] != null
              ? List<String>.from(jsonDecode(r['playlists'] as String))
              : null,
          thumbnailData: null, // not loaded — use thumbnailSmall
          thumbnailSmall: r['thumbnail_small'] as Uint8List?,
        );
      }
      return SongRecord.fromMap(r);
    }).toList();
  }

  /// Update the compressed thumbnail for a song.
  Future<void> updateThumbnailSmall(String path, Uint8List bytes) async {
    final db = await _getDb();
    await db.update(
      _songsTable,
      {'thumbnail_small': bytes},
      where: 'path = ?',
      whereArgs: [path],
    );
  }

  // ── PLAYLISTS helpers ─────────────────────────────────────────────────────

  /// Create a new named playlist. Returns the new row id.
  Future<int> createPlaylist(String name) async {
    final db = await _getDb();
    return db.insert(
      _playlistsTable,
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Delete a playlist and its song associations.
  Future<void> deletePlaylist(int id) async {
    final db = await _getDb();
    // PLAYLIST_SONGS rows are removed by ON DELETE CASCADE if FK is enforced;
    // delete them explicitly too for safety (sqflite doesn't always enforce FK).
    await db.delete(_playlistSongsTable,
        where: 'playlist_id = ?', whereArgs: [id]);
    await db.delete(_playlistsTable, where: 'id = ?', whereArgs: [id]);
  }

  /// Return all playlists ordered by name.
  Future<List<Map<String, dynamic>>> getAllPlaylists() async {
    final db = await _getDb();
    return db.query(_playlistsTable, orderBy: 'name ASC');
  }

  /// Add a song (by path) to a playlist. No-op if already present.
  Future<void> addSongToPlaylist(int playlistId, String songPath) async {
    final db = await _getDb();
    // Compute next position
    final rows = await db.query(
      _playlistSongsTable,
      columns: ['MAX(position) as max_pos'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    final maxPos = (rows.first['max_pos'] as int?) ?? -1;
    await db.insert(
      _playlistSongsTable,
      {
        'playlist_id': playlistId,
        'song_path': songPath,
        'position': maxPos + 1,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Remove a song from a playlist.
  Future<void> removeSongFromPlaylist(int playlistId, String songPath) async {
    final db = await _getDb();
    await db.delete(
      _playlistSongsTable,
      where: 'playlist_id = ? AND song_path = ?',
      whereArgs: [playlistId, songPath],
    );
  }

  /// Return all song records for a playlist, ordered by position.
  /// Selects only the lightweight columns — skips [thumbnail_data] (the full
  /// embedded art BLOB) and uses [thumbnail_small] instead so the list
  /// appears instantly without reading megabytes of image data per row.
  Future<List<SongRecord>> getSongsForPlaylist(int playlistId) async {
    final db = await _getDb();
    final rows = await db.rawQuery('''
      SELECT s.id, s.title, s.author, s.album, s.path,
             s.folder_locations, s.playlists, s.thumbnail_small
      FROM $_songsTable s
      INNER JOIN $_playlistSongsTable ps ON ps.song_path = s.path
      WHERE ps.playlist_id = ?
      ORDER BY ps.position ASC
    ''', [playlistId]);
    return rows.map((r) => SongRecord(
      id: r['id'] as int?,
      title: r['title'] as String,
      author: r['author'] as String,
      album: r['album'] as String?,
      path: r['path'] as String,
      folderLocations: r['folder_locations'] != null
          ? List<String>.from(jsonDecode(r['folder_locations'] as String))
          : [],
      playlists: r['playlists'] != null
          ? List<String>.from(jsonDecode(r['playlists'] as String))
          : null,
      thumbnailData: null,
      thumbnailSmall: r['thumbnail_small'] as Uint8List?,
    )).toList();
  }

  /// Return the set of song paths already in a playlist (for checkbox state).
  Future<Set<String>> getPathsInPlaylist(int playlistId) async {
    final db = await _getDb();
    final rows = await db.query(
      _playlistSongsTable,
      columns: ['song_path'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    return rows.map((r) => r['song_path'] as String).toSet();
  }
}
