import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_image_compress/flutter_image_compress.dart';
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

class _ScanArgs {
  final String dirPath;
  _ScanArgs(this.dirPath);
}

/// Runs entirely on a background isolate. Scans [dirPath] for music files and
/// reads their text metadata + raw album-art bytes.
/// Compression happens back on the main isolate (flutter_image_compress needs
/// platform channels which are not available inside a compute isolate).
List<_RawSongInfo> _scanAndReadMetadata(_ScanArgs args) {
  final dir = Directory(args.dirPath);
  final result = <_RawSongInfo>[];

  for (final entity in dir.listSync()) {
    if (entity is! File || !_isMusicFilePath(entity.path)) continue;

    try {
      final meta = readMetadata(entity, getImage: false);
      final author =
          meta.artist?.isNotEmpty == true ? meta.artist! : 'Unknown artist';
      final album = meta.album?.isNotEmpty == true ? meta.album : null;
      final title = entity.path
          .split(Platform.pathSeparator)
          .last
          .replaceAll(RegExp(r'\.(mp3|flac)$', caseSensitive: false), '');

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

      result.add(_RawSongInfo(
        path: entity.path,
        folderPath: args.dirPath,
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

/// Keeps the SONGS table up-to-date when the app opens.
///
/// For every new song it also creates a compressed `thumbnail_small`
/// (~96×96 JPEG, ≤15 KB) so the playlist list can load artwork from a single
/// DB query instead of decoding multi-hundred-KB embedded tags at scroll time.
class SongSyncService {
  final DatabaseService _db;

  SongSyncService(this._db);

  /// Sync all songs found under [rootDir] and its immediate subdirectories.
  Future<void> syncLibrary(Directory rootDir) async {
    if (!rootDir.existsSync()) return;

    final folders = rootDir.listSync().whereType<Directory>().toList();
    folders.insert(0, rootDir);

    final indexedPaths = await _db.getAllIndexedPaths();

    for (final folder in folders) {
      await _syncFolder(folder, indexedPaths);
    }
  }

  Future<void> _syncFolder(
      Directory folder, Set<String> indexedPaths) async {
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

    // ── Insert brand-new songs ─────────────────────────────────────────────
    if (newPaths.isNotEmpty) {
      final rawList = await compute(_scanAndReadMetadata, _ScanArgs(folder.path));

      final newPathsSet = newPaths.toSet();
      final toInsert = <SongRecord>[];

      for (final raw in rawList) {
        if (!newPathsSet.contains(raw.path)) continue;

        // Compress art on the main isolate (requires platform channels)
        final small = await _compressArt(raw.thumbnailData);

        toInsert.add(SongRecord(
          title: raw.title,
          author: raw.author,
          album: raw.album,
          path: raw.path,
          folderLocations: [raw.folderPath],
          playlists: null,
          thumbnailData: raw.thumbnailData,
          thumbnailSmall: small,
        ));
        indexedPaths.add(raw.path);
      }

      await _db.upsertSongs(toInsert);
    }

    // ── Update folder_locations for songs seen in a new folder ─────────────
    for (final path in existingInNewFolder) {
      final record = await _db.getSongByPath(path);
      if (record == null) continue;
      final folderPath = folder.path;
      if (!record.folderLocations.contains(folderPath)) {
        final updated = [...record.folderLocations, folderPath];
        await _db.updateSongFolderLocations(path, updated);
      }

      // Back-fill thumbnail_small if it was stored before this feature existed
      if (record.thumbnailSmall == null && record.thumbnailData != null) {
        final small = await _compressArt(record.thumbnailData);
        if (small != null) {
          await _db.updateThumbnailSmall(path, small);
        }
      }
    }
  }

  /// Compress [art] to a 96×96 JPEG at quality 75.
  /// Returns null if art is null or compression fails.
  static Future<Uint8List?> _compressArt(Uint8List? art) async {
    if (art == null) return null;
    try {
      final result = await FlutterImageCompress.compressWithList(
        art,
        minWidth: 96,
        minHeight: 96,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      // Only use the compressed version if it's actually smaller
      return result.length < art.length ? result : art;
    } catch (_) {
      return art; // fall back to original on error
    }
  }
}
