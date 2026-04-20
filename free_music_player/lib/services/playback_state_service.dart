import 'package:shared_preferences/shared_preferences.dart';

/// Service to persist and restore playback state across app restarts
class PlaybackStateService {
  static const String _currentSongIndexKey = 'current_song_index';
  static const String _currentPlaylistPathKey = 'current_playlist_path';
  static const String _playbackPositionKey = 'playback_position';
  static const String _isShuffleKey = 'is_shuffle';
  static const String _isRepeatKey = 'is_repeat';

  final SharedPreferences _prefs;

  PlaybackStateService(this._prefs);

  /// Initialize the service
  static Future<PlaybackStateService> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return PlaybackStateService(prefs);
  }

  /// Save current song index
  Future<void> saveCurrentSongIndex(int? index) async {
    if (index != null) {
      await _prefs.setInt(_currentSongIndexKey, index);
    } else {
      await _prefs.remove(_currentSongIndexKey);
    }
  }

  /// Get saved song index
  int? getCurrentSongIndex() {
    return _prefs.getInt(_currentSongIndexKey);
  }

  /// Save current playlist path
  Future<void> saveCurrentPlaylistPath(String? path) async {
    if (path != null && path.isNotEmpty) {
      await _prefs.setString(_currentPlaylistPathKey, path);
    } else {
      await _prefs.remove(_currentPlaylistPathKey);
    }
  }

  /// Get saved playlist path
  String? getCurrentPlaylistPath() {
    return _prefs.getString(_currentPlaylistPathKey);
  }

  /// Save playback position in milliseconds
  Future<void> savePlaybackPosition(int positionMs) async {
    await _prefs.setInt(_playbackPositionKey, positionMs);
  }

  /// Get saved playback position in milliseconds
  int? getPlaybackPosition() {
    return _prefs.getInt(_playbackPositionKey);
  }

  /// Save shuffle state
  Future<void> saveShuffleState(bool isShuffle) async {
    await _prefs.setBool(_isShuffleKey, isShuffle);
  }

  /// Get saved shuffle state
  bool getShuffleState() {
    return _prefs.getBool(_isShuffleKey) ?? false;
  }

  /// Save repeat mode (0 = off, 1 = all, 2 = one)
  Future<void> saveRepeatMode(int mode) async {
    await _prefs.setInt(_isRepeatKey, mode);
  }

  /// Get saved repeat mode
  int getRepeatMode() {
    return _prefs.getInt(_isRepeatKey) ?? 0;
  }

  /// Clear all saved state
  Future<void> clearState() async {
    await _prefs.remove(_currentSongIndexKey);
    await _prefs.remove(_currentPlaylistPathKey);
    await _prefs.remove(_playbackPositionKey);
    await _prefs.remove(_isShuffleKey);
    await _prefs.remove(_isRepeatKey);
  }

  /// Check if there is saved state
  bool hasSavedState() {
    return _prefs.containsKey(_currentSongIndexKey) &&
        _prefs.containsKey(_currentPlaylistPathKey);
  }
}

// Made with Bob
