import 'dart:io';

class Song {
  final String songName;
  final String artistName;
  final String albumArtImagePath;
  final FileSystemEntity audioPath;

  Song({
    required this.songName,
    required this.artistName,
    required this.albumArtImagePath,
    required this.audioPath,
  });
}
