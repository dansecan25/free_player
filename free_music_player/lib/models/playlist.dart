import 'dart:io';

import 'package:free_music_player/models/song.dart';

class Playlist {
  final String playlistName;
  List<Song>? playlistSongs;
  final Directory directoryPath;
  int? songCount; // Cached song count to avoid repeated file system access

  Playlist({
    required this.playlistName,
    required this.playlistSongs,
    required this.directoryPath,
    this.songCount,
  });

  void setSongs(List<Song> songs){
    playlistSongs=songs;
    songCount = songs.length; // Update count when songs are set
  }

  void setSongCount(int count) {
    songCount = count;
  }
}
