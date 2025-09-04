import 'dart:io';
import 'dart:typed_data';

class Song {
  final String songName;
  final String artistName;
  final Uint8List? albumArtImagePathBytes;
  final FileSystemEntity audioPath;

  Song({
    required this.songName,
    required this.artistName,
    required this.albumArtImagePathBytes,
    required this.audioPath,
  });
}
