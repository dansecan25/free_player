import 'dart:io';

import 'package:flutter/foundation.dart';

class Song {
  final String songName;
  final String artistName;
  final FileSystemEntity audioPath;

  /// List thumbnail. A notifier, so a tile repaints alone when artwork changes.
  final ValueNotifier<Uint8List?> albumArtNotifier;

  Song({
    required this.songName,
    required this.artistName,
    required Uint8List? albumArtImagePathBytes,
    required this.audioPath,
  }) : albumArtNotifier = ValueNotifier<Uint8List?>(albumArtImagePathBytes);

  /// Full path of the audio file, which identifies the song.
  String get path => audioPath.path;

  Uint8List? get albumArtImagePathBytes => albumArtNotifier.value;
  set albumArtImagePathBytes(Uint8List? bytes) => albumArtNotifier.value = bytes;
}
