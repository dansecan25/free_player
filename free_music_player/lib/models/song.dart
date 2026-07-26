import 'dart:io';
import 'dart:typed_data';

class Song {
  final String songName;
  final String artistName;
  // Not final: artwork is loaded in the background (after the song list is
  // already shown) and filled in here once it's decoded, so the UI never
  // has to block waiting for every album art image before it can render.
  Uint8List? albumArtImagePathBytes;
  final FileSystemEntity audioPath;

  Song({
    required this.songName,
    required this.artistName,
    required this.albumArtImagePathBytes,
    required this.audioPath,
  });
}
