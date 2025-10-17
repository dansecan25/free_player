import 'dart:io';

import 'package:free_music_player/models/song.dart';

class Playlist {
  final String playlistName;
  List<Song>? playlistSongs;
  final Directory directoryPath;

  Playlist({
    required this.playlistName,
    required this.playlistSongs,
    required this.directoryPath,
  });

  void setSongs(List<Song> songs){
    playlistSongs=songs;
  }
}
