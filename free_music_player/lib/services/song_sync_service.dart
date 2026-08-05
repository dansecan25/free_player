import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:free_music_player/models/song_record.dart';
import 'package:free_music_player/services/database_service.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:id3/id3.dart';

// ── Isolate-safe helpers ─────────────────────────────────────────────────────

bool _isMusicFilePath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp3') || lower.endsWith('.flac');
}

/// Lightweight description of one audio file, safe to cross an isolate
/// boundary (all primitive types).
class _RawSongInfo {
  final String path;
  final String folderPath;
  final String title;
  final String author;
  final String? album;
  final Uint8List? thumbnailData;

  _RawSongInfo({
    required this.path,
    required this.folderPath,
    required this.title,
    required this.author,
    this.album,
    this.thumbnailData,
  });
}

/// Arguments passed into the background isolate as a single object so we can
/// use [compute] (which only accepts one argument).
class _ScanArgs {
  final String dirPath;
  _ScanArgs(this.dirPath);
}

/// Runs entirely on a background isolate. Scans [dirPath] for music files,
/// reads all their metadata (including album art), and returns one
/// [_RawSongInfo] per file.
List<_RawSongInfo> _scanAndReadMetadata(_ScanArgs args) {
  final dir = Directory(args.dirPath);
  final result = <_RawSongInfo>[];

  for (final entity in dir.listSync()) {
    if (entity is! File || !_isMusicFilePath(entity.path)) continue;

    try {
      // ── Text metadata ──────────────────────────────────────────────────
      final meta = readMetadata(entity, getImage: false);
      final author =
          meta.artist?.isNotEmpty == true ? meta.artist! : 'Unknown artist';
      final album = meta.album?.isNotEmpty == true ? meta.album : null;
      final title = entity.path
          .split(Platform.pathSeparator)
          .last
          .replaceAll(RegExp(r'\.(mp3|flac)$', caseSensitive: false), '');

      // ── Album art ─────────────────────────────────────────────────────
      Uint8List? art;
      if (entity.path.toLowerCase().endsWith('.mp3')) {
        try {
          final bytes = entity.readAsBytesSync();
          final mp3 = MP3Instance(bytes);
          if (mp3.parseTagsSync()) {
            final tags = mp3.getMetaTags();
            if (tags != null && tags.containsKey('APIC')) {
              final apic = tags['APIC'];
              if (apic != null && apic['base64'] != null) {
                art = base64Decode(apic['base64'] as String);
              }
            }
          }
        } catch (_) {
          // No art — that's fine
        }
      }

      final folderPath = args.dirPath;
      result.add(_RawSongInfo(
        path: entity.path,
        folderPath: folderPath,
        title: title,
        author: author,
        album: album,
        thumbnailData: art,
      ));
    } catch (_) {
      // Skip unreadable files
    }
  }
  return result;
}

// ── SongSyncService ──────────────────────────────────────────────────────────

/// Responsible for keeping the SONGS table up-to-date when the app opens.
///
/// Algorithm (per folder under the root music directory):
///   1. Collect all music file paths in the folder.
///   2. Query the DB for which of those paths are already indexed.
///   3. For brand-new paths: read full metadata on a background isolate and
///      insert them.
///   4. For paths already indexed that now appear in a new folder: append that
///      folder to their [folderLocations] list.
class SongSyncService {
  final DatabaseService _db;

  SongSyncService(this._db);

  /// Sync all songs found under [rootDir] and its immediate subdirectories.
  /// Call this once during app initialisation (from [PlaylistProvider]).
  Future<void> syncLibrary(Directory rootDir) async {
    if (!rootDir.existsSync()) return;

    // Collect all playlist directories (immediate sub-folders)
    final folders = rootDir
        .listSync()
        .whereType<Directory>()
        .toList();

    // Also include the root itself if it has music files directly
    folders.insert(0, rootDir);

    // Already-indexed paths (fast lookup)
    final indexedPaths = await _db.getAllIndexedPaths();

    for (final folder in folders) {
      await _syncFolder(folder, indexedPaths);
    }
  }

  Future<void> _syncFolder(
      Directory folder, Set<String> indexedPaths) async {
    // List all music files in this folder (non-recursive)
    final musicFiles = folder
        .listSync()
        .whereType<File>()
        .where((f) => _isMusicFilePath(f.path))
        .toList();

    if (musicFiles.isEmpty) return;

    final newPaths = <String>[];
    final existingInNewFolder = <String>[];

    for (final f in musicFiles) {
      if (!indexedPaths.contains(f.path)) {
        newPaths.add(f.path);
      } else {
        existingInNewFolder.add(f.path);
      }
    }

    // ── Insert brand-new songs ───────────────────────────────────────────
    if (newPaths.isNotEmpty) {
      // Scan metadata on a background isolate
      final rawList = await compute(
        _scanAndReadMetadata,
        _ScanArgs(folder.path),
      );

      // Filter to only those that were actually new (the isolate scanned the
      // whole folder, but some might have been indexed by a previous iteration
      // of this loop when the same file appears in multiple folders).
      final newPathsSet = newPaths.toSet();
      final toInsert = <SongRecord>[];

      for (final raw in rawList) {
        if (!newPathsSet.contains(raw.path)) continue;
        toInsert.add(SongRecord(
          title: raw.title,
          author: raw.author,
          album: raw.album,
          path: raw.path,
          folderLocations: [raw.folderPath],
          playlists: null,
          thumbnailData: raw.thumbnailData,
        ));
        // Mark as indexed so later folders don't re-insert the same file
        indexedPaths.add(raw.path);
      }

      await _db.upsertSongs(toInsert);
    }

    // ── Update folder_locations for songs seen in a new folder ───────────
    for (final path in existingInNewFolder) {
      final record = await _db.getSongByPath(path);
      if (record == null) continue;
      final folderPath = folder.path;
      if (!record.folderLocations.contains(folderPath)) {
        final updated = [...record.folderLocations, folderPath];
        await _db.updateSongFolderLocations(path, updated);
      }
    }
  }
}
