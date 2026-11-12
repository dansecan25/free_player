import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:free_music_player/constants/library_limits.dart';
import 'package:path/path.dart' as p;

bool isMusicFilePath(String path) =>
    LibraryLimits.musicExtensions.contains(p.extension(path).toLowerCase());

/// Song name shown in lists: the file name without its extension.
String songNameFromPath(String path) => p.basenameWithoutExtension(path);

/// Metadata of one audio file. Only plain fields, so it can cross isolates.
class AudioFileInfo {
  final String path;
  final String title;
  final String artist;
  final String? album;
  final Uint8List? artwork;

  const AudioFileInfo({
    required this.path,
    required this.title,
    required this.artist,
    this.album,
    this.artwork,
  });
}

/// Result of listing the music folder and its playlist sub-folders.
class LibraryListing {
  /// Every music file found, by full path.
  final Set<String> musicFiles;

  /// Folders that could not be read. Songs inside them are not treated as
  /// deleted, so a temporary permission or mount problem never wipes them.
  final Set<String> unreadableFolders;

  const LibraryListing(this.musicFiles, this.unreadableFolders);
}

/// Lists music files in [rootPath] and its direct sub-folders.
/// Runs on a background isolate.
LibraryListing listLibrary(String rootPath) {
  final musicFiles = <String>{};
  final unreadable = <String>{};

  void collect(Directory folder) {
    try {
      for (final entity in folder.listSync(followLinks: false)) {
        if (entity is File && isMusicFilePath(entity.path)) {
          musicFiles.add(entity.path);
        }
      }
    } on FileSystemException {
      unreadable.add(folder.path);
    }
  }

  final root = Directory(rootPath);
  collect(root);
  try {
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is Directory) collect(entity);
    }
  } on FileSystemException {
    unreadable.add(rootPath);
  }
  return LibraryListing(musicFiles, unreadable);
}

/// Reads tags and embedded artwork for [paths]. Runs on a background isolate.
/// Files whose tags can't be read still get an entry named after the file, so
/// they are playable and aren't rescanned on every sync.
List<AudioFileInfo> readAudioFiles(List<String> paths) {
  return paths.map((path) {
    try {
      final metadata = readMetadata(File(path), getImage: true);
      final artist = metadata.artist?.trim() ?? '';
      final album = metadata.album?.trim() ?? '';
      return AudioFileInfo(
        path: path,
        title: songNameFromPath(path),
        artist: artist.isNotEmpty ? artist : LibraryLimits.unknownArtist,
        album: album.isNotEmpty ? album : null,
        artwork: _frontCover(metadata.pictures),
      );
    } catch (_) {
      return AudioFileInfo(
        path: path,
        title: songNameFromPath(path),
        artist: LibraryLimits.unknownArtist,
      );
    }
  }).toList();
}

Uint8List? _frontCover(List<Picture> pictures) {
  if (pictures.isEmpty) return null;
  final front = pictures.where((pic) => pic.pictureType == PictureType.coverFront);
  return (front.isNotEmpty ? front.first : pictures.first).bytes;
}
