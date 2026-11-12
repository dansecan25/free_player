import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/utils/song_sorting.dart';

Song _song(String name, [String artist = 'Artist']) => Song(
      songName: name,
      artistName: artist,
      albumArtImagePathBytes: null,
      audioPath: File('/music/$name.mp3'),
    );

void main() {
  final songs = [_song('banana'), _song('Apple'), _song('cherry'), _song('apple', 'Zed')];

  test('sorts by name ignoring case, then by artist', () {
    expect(
      sortSongsByName(songs).map((s) => '${s.songName}/${s.artistName}'),
      ['Apple/Artist', 'apple/Zed', 'banana/Artist', 'cherry/Artist'],
    );
  });

  test('reversed gives Z–A', () {
    expect(sortSongsByName(songs, reversed: true).first.songName, 'cherry');
  });

  test('does not change the original list', () {
    sortSongsByName(songs);
    expect(songs.first.songName, 'banana');
  });

  test('filters by name or artist, ignoring case and spaces', () {
    expect(filterSongs(songs, ' ZED ').single.artistName, 'Zed');
    expect(filterSongs(songs, 'an').map((s) => s.songName), ['banana']);
    expect(filterSongs(songs, ''), hasLength(4));
  });
}
