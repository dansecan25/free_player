import 'package:free_music_player/models/song.dart';

/// Case-insensitive A–Z order by song name, then by artist.
int compareSongsByName(Song a, Song b) {
  final byName = a.songName.toLowerCase().compareTo(b.songName.toLowerCase());
  if (byName != 0) return byName;
  return a.artistName.toLowerCase().compareTo(b.artistName.toLowerCase());
}

/// Returns a new list sorted by name, reversed (Z–A) when [reversed] is true.
List<Song> sortSongsByName(Iterable<Song> songs, {bool reversed = false}) {
  final sorted = songs.toList()..sort(compareSongsByName);
  return reversed ? sorted.reversed.toList() : sorted;
}

/// Songs whose name or artist contains [query], ignoring case.
List<Song> filterSongs(Iterable<Song> songs, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return songs.toList();
  return songs
      .where((song) =>
          song.songName.toLowerCase().contains(needle) ||
          song.artistName.toLowerCase().contains(needle))
      .toList();
}
