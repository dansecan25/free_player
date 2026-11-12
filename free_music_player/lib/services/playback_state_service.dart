import 'package:shared_preferences/shared_preferences.dart';

/// Persists what was playing so it can be restored after a restart.
///
/// The song is stored by file path, not by list index, because indexes change
/// when the queue is shuffled or a song is removed.
class PlaybackStateService {
  static const String _songPathKey = 'current_song_path';
  static const String _folderPathKey = 'current_playlist_path';
  static const String _positionKey = 'playback_position';
  static const String _shuffleKey = 'is_shuffle';
  static const String _repeatKey = 'is_repeat';
  static const String _sortReversedKey = 'is_sort_reversed';

  final SharedPreferences _prefs;

  PlaybackStateService(this._prefs);

  static Future<PlaybackStateService> initialize() async =>
      PlaybackStateService(await SharedPreferences.getInstance());

  SharedPreferences get preferences => _prefs;

  Future<void> _setOrRemove(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  Future<void> saveCurrentSongPath(String? path) => _setOrRemove(_songPathKey, path);
  String? getCurrentSongPath() => _prefs.getString(_songPathKey);

  /// Folder playlist the queue came from. Null for queues that can't be
  /// rebuilt from a folder (All songs, user playlists), which aren't restored.
  Future<void> saveCurrentPlaylistPath(String? path) =>
      _setOrRemove(_folderPathKey, path);
  String? getCurrentPlaylistPath() => _prefs.getString(_folderPathKey);

  Future<void> savePlaybackPosition(int positionMs) =>
      _prefs.setInt(_positionKey, positionMs);
  int? getPlaybackPosition() => _prefs.getInt(_positionKey);

  Future<void> saveShuffleState(bool isShuffle) => _prefs.setBool(_shuffleKey, isShuffle);
  bool getShuffleState() => _prefs.getBool(_shuffleKey) ?? false;

  /// 0 = off, 1 = repeat all, 2 = repeat one.
  Future<void> saveRepeatMode(int mode) => _prefs.setInt(_repeatKey, mode);
  int getRepeatMode() => _prefs.getInt(_repeatKey) ?? 0;

  Future<void> saveSortReversed(bool isReversed) =>
      _prefs.setBool(_sortReversedKey, isReversed);
  bool getSortReversed() => _prefs.getBool(_sortReversedKey) ?? false;
}
