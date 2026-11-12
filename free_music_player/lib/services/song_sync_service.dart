import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:free_music_player/constants/library_limits.dart';
import 'package:free_music_player/models/song_record.dart';
import 'package:free_music_player/services/database_service.dart';
import 'package:free_music_player/utils/audio_files.dart';
import 'package:path/path.dart' as p;

/// Keeps the SONGS table in step with the files in the music folder.
///
/// A sync lists the folder on a background isolate, reads tags only for files
/// that are new, and removes rows whose files are gone. Unchanged files cost
/// nothing beyond the folder listing, so it's cheap to run on every resume.
class SongSyncService {
  final DatabaseService _db;

  SongSyncService(this._db);

  /// Syncs [rootDir] and its direct sub-folders. Returns true when songs were
  /// added or removed.
  Future<bool> syncLibrary(Directory rootDir) async {
    if (!await rootDir.exists()) return false;

    final listing = await compute(listLibrary, rootDir.path);
    final indexed = await _db.getAllIndexedPaths();

    final added = listing.musicFiles.difference(indexed).toList();
    final removed = indexed.where((path) =>
        !listing.musicFiles.contains(path) &&
        !listing.unreadableFolders.contains(p.dirname(path)));

    final removedList = removed.toList();
    await _db.deleteSongsByPaths(removedList);
    await _indexNewFiles(added);
    return added.isNotEmpty || removedList.isNotEmpty;
  }

  Future<void> _indexNewFiles(List<String> paths) async {
    for (var start = 0; start < paths.length; start += LibraryLimits.metadataBatchSize) {
      final end = (start + LibraryLimits.metadataBatchSize).clamp(0, paths.length);
      final infos = await compute(readAudioFiles, paths.sublist(start, end));
      final records = <SongRecord>[];
      for (final info in infos) {
        records.add(SongRecord(
          title: info.title,
          author: info.artist,
          album: info.album,
          path: info.path,
          folderLocations: [p.dirname(info.path)],
          thumbnailData: info.artwork,
          // Compression uses a platform channel, so it runs on this isolate.
          thumbnailSmall: await compressThumbnail(info.artwork),
        ));
      }
      await _db.upsertSongs(records);
    }
  }

  /// Small JPEG used by list tiles, or null when there's no artwork.
  static Future<Uint8List?> compressThumbnail(Uint8List? artwork) async {
    if (artwork == null) return null;
    try {
      final result = await FlutterImageCompress.compressWithList(
        artwork,
        minWidth: LibraryLimits.thumbnailSize,
        minHeight: LibraryLimits.thumbnailSize,
        quality: LibraryLimits.thumbnailQuality,
        format: CompressFormat.jpeg,
      );
      return result.length < artwork.length ? result : artwork;
    } catch (error) {
      debugPrint('Could not compress artwork: $error');
      return artwork;
    }
  }
}
