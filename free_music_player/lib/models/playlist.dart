import 'package:free_music_player/models/song.dart';

class Playlist {
  final String playlistName;
  final List<Song> playlistSongs;

  Playlist({
    required this.playlistName,
    required this.playlistSongs,
  });
}
