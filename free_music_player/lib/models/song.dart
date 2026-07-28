import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class Song {
  final String songName;
  final String artistName;
  final FileSystemEntity audioPath;

  /// Album art bytes, loaded in the background after the song list is
  /// already shown. Backed by a ValueNotifier (instead of a plain mutable
  /// field) so that when artwork arrives, only the one widget listening to
  /// this specific song's notifier repaints -- not the whole song list/page.
  /// This is what lets you scroll and tap smoothly while artwork is still
  /// streaming in for other songs.
  final ValueNotifier<Uint8List?> albumArtNotifier;

  Song({
    required this.songName,
    required this.artistName,
    required Uint8List? albumArtImagePathBytes,
    required this.audioPath,
  }) : albumArtNotifier = ValueNotifier<Uint8List?>(albumArtImagePathBytes);

  // Kept so every existing call site (media_controls, song_page,
  // playlist_provider) can keep reading/writing `song.albumArtImagePathBytes`
  // exactly as before -- this just routes through the notifier underneath.
  Uint8List? get albumArtImagePathBytes => albumArtNotifier.value;
  set albumArtImagePathBytes(Uint8List? bytes) => albumArtNotifier.value = bytes;
}
