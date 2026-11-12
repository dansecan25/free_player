import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/models/song_record.dart';
import 'package:free_music_player/services/audio_handler.dart';
import 'package:free_music_player/services/database_service.dart';
import 'package:free_music_player/services/playback_state_service.dart';
import 'package:free_music_player/services/song_sync_service.dart';
import 'package:free_music_player/utils/song_sorting.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Song for list display, built from a database row (thumbnail only).
Song songFromRecord(SongRecord record) => Song(
      songName: record.title,
      artistName: record.author,
      albumArtImagePathBytes: record.thumbnailSmall,
      audioPath: File(record.path),
    );

/// Owns the music library (folder playlists) and the playback queue.
class PlaylistProvider extends ChangeNotifier {
  final DatabaseService dbService;
  final AudioPlayerHandler audioHandler;
  final PlaybackStateService? stateService;
  late final SongSyncService _syncService;

  String _musicDirectoryPath = '';
  List<Playlist> _playlists = [];
  bool _isSyncing = false;
  int _libraryRevision = 0;
  Future<void>? _activeSync;
  bool _syncAgain = false;

  List<Song>? _currentSongList;
  List<Song>? _originalSongList;
  int? _currentSongIndex;
  String? _queueFolderPath;

  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isShuffle = false;
  int _isRepeat = 0;

  Timer? _stateSaveTimer;
  File? _currentAlbumArtFile;
  Uint8List? _currentArtwork;
  String? _currentArtworkPath;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  PlaylistProvider(this.audioHandler, {this.stateService, DatabaseService? database})
      : dbService = database ?? DatabaseService() {
    _syncService = SongSyncService(dbService);
    _isShuffle = stateService?.getShuffleState() ?? false;
    _isRepeat = stateService?.getRepeatMode() ?? 0;
    _listenToPlayer();
    _stateSaveTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _saveCurrentState());
    _initialize();
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  String get musicDirectoryPath => _musicDirectoryPath;
  /// Replaced (never mutated in place) when the folders change, so widgets
  /// can select it without rebuilding on every playback position tick.
  List<Playlist> get playlists => _playlists;

  /// True while the music folder is being scanned.
  bool get isSyncing => _isSyncing;

  /// Increases whenever songs were added or removed, so open lists reload.
  int get libraryRevision => _libraryRevision;

  int? get currentIndex => _currentSongIndex;
  int get playlistLength => _currentSongList?.length ?? 0;
  bool get isPlaying => audioHandler.playbackState.value.playing;
  bool get isShuffling => _isShuffle;
  int get isRepeating => _isRepeat;
  Duration get currentDuration => _currentDuration;
  Duration get totalDuration => _totalDuration;

  /// Full-size artwork of the current song, falling back to its thumbnail.
  Uint8List? get currentArtwork {
    final song = currentSongPlaying;
    if (song == null) return null;
    return song.path == _currentArtworkPath
        ? _currentArtwork ?? song.albumArtImagePathBytes
        : song.albumArtImagePathBytes;
  }

  Song? get currentSongPlaying {
    final list = _currentSongList;
    final index = _currentSongIndex;
    if (list == null || index == null || index < 0 || index >= list.length) {
      return null;
    }
    return list[index];
  }

  // ── Library ───────────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    try {
      _musicDirectoryPath = await dbService.getMainFolderPath() ?? '';
      if (_musicDirectoryPath.isNotEmpty) {
        await _rebuildPlaylists(); // show what's indexed right away
        await refreshLibrary();
      }
      await _restorePlaybackState();
    } catch (error) {
      debugPrint('Error loading the library: $error');
    }
    notifyListeners();
  }

  Future<void> setMusicDirectory(String path) async {
    await dbService.storeMainFolderPath(path);
    _musicDirectoryPath = path;
    await refreshLibrary(force: true);
  }

  /// Rescans the music folder and updates playlists if anything changed.
  /// Calls that arrive while a scan is running trigger one more scan after it.
  Future<void> refreshLibrary({bool force = false}) {
    if (_musicDirectoryPath.isEmpty) return Future.value();
    if (_activeSync != null) {
      _syncAgain = true;
      return _activeSync!;
    }
    _activeSync = _runSync(force).whenComplete(() => _activeSync = null);
    return _activeSync!;
  }

  Future<void> _runSync(bool force) async {
    _isSyncing = true;
    notifyListeners();
    try {
      var changed = force;
      do {
        _syncAgain = false;
        changed |= await _syncService.syncLibrary(Directory(_musicDirectoryPath));
      } while (_syncAgain);
      if (changed) {
        await _rebuildPlaylists();
        _libraryRevision++;
      }
    } catch (error) {
      debugPrint('Error syncing the library: $error');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Rebuilds the folder playlists, with song counts from the database so
  /// they always match what the playlist page shows.
  Future<void> _rebuildPlaylists() async {
    final root = Directory(_musicDirectoryPath);
    if (!await root.exists()) {
      _playlists = [];
      return;
    }
    final counts = await dbService.getSongCountsByFolder();
    final folders = await root.list(followLinks: false).where((e) => e is Directory).toList();
    final playlists = folders
        .map((folder) => Playlist(
              playlistName: p.basename(folder.path),
              playlistSongs: null,
              directoryPath: Directory(folder.path),
              songCount: counts[folder.path] ?? 0,
            ))
        .toList()
      ..sort((a, b) =>
          a.playlistName.toLowerCase().compareTo(b.playlistName.toLowerCase()));
    _playlists = playlists;
    notifyListeners();
  }

  /// Songs in a folder playlist, sorted by name.
  Future<List<Song>> loadFolderSongs(Directory folder) async {
    var records = await dbService.getSongsForFolder(folder.path);
    if (records.isEmpty) {
      // First open before the startup scan finished.
      await refreshLibrary();
      records = await dbService.getSongsForFolder(folder.path);
    }
    return sortSongsByName(records.map(songFromRecord));
  }

  // ── Queue ─────────────────────────────────────────────────────────────────

  /// Plays [song] with [sourceList] as the queue. Pass [folderPath] when the
  /// list is a folder playlist, so the queue can be restored after a restart.
  void playFromList(List<Song> sourceList, Song song, {String? folderPath}) {
    _queueFolderPath = folderPath;
    _originalSongList = List<Song>.from(sourceList);
    _currentSongList = _isShuffle
        ? (List<Song>.from(sourceList)..shuffle())
        : List<Song>.from(sourceList);
    final index = _currentSongList!.indexWhere((s) => s.path == song.path);
    _currentSongIndex = index == -1 ? 0 : index;
    _play();
  }

  void shuffle() {
    _isShuffle = !_isShuffle;
    stateService?.saveShuffleState(_isShuffle);

    final original = _originalSongList;
    if (original != null && original.isNotEmpty) {
      final current = currentSongPlaying;
      _currentSongList = _isShuffle
          ? (List<Song>.from(original)..shuffle())
          : List<Song>.from(original);
      if (current != null) {
        final index = _currentSongList!.indexWhere((s) => s.path == current.path);
        _currentSongIndex = index == -1 ? 0 : index;
      }
    }
    notifyListeners();
  }

  /// Cycles off → repeat all → repeat one.
  void repeat() {
    _isRepeat = (_isRepeat + 1) % 3;
    stateService?.saveRepeatMode(_isRepeat);
    notifyListeners();
  }

  Future<void> playNextSong() async {
    final list = _currentSongList;
    if (list == null || list.isEmpty || _currentSongIndex == null) return;
    _currentSongIndex = (_currentSongIndex! + 1) % list.length;
    await _play();
  }

  Future<void> previousSong() async {
    final list = _currentSongList;
    if (list == null || list.isEmpty || _currentSongIndex == null) return;
    if (_currentDuration.inSeconds > 5) {
      await seek(Duration.zero);
      return;
    }
    _currentSongIndex = (_currentSongIndex! - 1 + list.length) % list.length;
    await _play();
  }

  Future<void> pauseOrResume() async {
    if (currentSongPlaying == null) return;
    if (audioHandler.playbackState.value.playing) {
      await audioHandler.pause();
      await _saveCurrentState();
    } else {
      await audioHandler.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration position) => audioHandler.seek(position);

  Future<void> _play() => _loadCurrentSong(autoplay: true);

  /// Reloads and plays the current song, used to recover from player errors.
  Future<void> reloadCurrentSong() => _play();

  /// Loads the current song into the player, and plays it if [autoplay].
  Future<void> _loadCurrentSong({required bool autoplay, Duration? startAt}) async {
    final song = currentSongPlaying;
    if (song == null) return;
    try {
      await _cleanupAlbumArt();
      final artUri = await _writeArtworkForNotification(song);
      await audioHandler.setAudioSource(AudioSource.uri(Uri.file(song.path)));
      if (startAt != null) await audioHandler.seek(startAt);
      await audioHandler.setMediaItem(MediaItem(
        id: song.path,
        title: song.songName,
        artist: song.artistName,
        duration: audioHandler.player.duration,
        artUri: artUri,
      ));
      if (autoplay) await audioHandler.play();
      await _saveCurrentState();
    } catch (error) {
      debugPrint('Error playing ${song.path}: $error');
      await _cleanupAlbumArt();
    }
    notifyListeners();
  }

  /// The media notification needs artwork as a file, so the full-size art is
  /// written to a temporary file that's replaced on every song change.
  Future<Uri?> _writeArtworkForNotification(Song song) async {
    final artwork = await dbService.getFullArtwork(song.path) ?? song.albumArtImagePathBytes;
    _currentArtwork = artwork;
    _currentArtworkPath = song.path;
    if (artwork == null) return null;
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path,
        'album_art_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await file.writeAsBytes(artwork);
    _currentAlbumArtFile = file;
    return Uri.file(file.path);
  }

  Future<void> _cleanupAlbumArt() async {
    final file = _currentAlbumArtFile;
    _currentAlbumArtFile = null;
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Error deleting album art file: $error');
    }
  }

  void _listenToPlayer() {
    final player = audioHandler.player;
    _subscriptions.add(player.durationStream.listen((duration) {
      _totalDuration = duration ?? Duration.zero;
      notifyListeners();
    }));
    _subscriptions.add(player.positionStream.listen((position) {
      _currentDuration = position;
      notifyListeners();
    }));
    _subscriptions.add(player.processingStateStream.listen((state) {
      if (state != ProcessingState.completed || currentSongPlaying == null) return;
      if (_isRepeat == 2) {
        _play();
      } else if (_isRepeat == 1 || _currentSongIndex! + 1 < playlistLength) {
        playNextSong();
      }
    }));
  }

  // ── Deleting ──────────────────────────────────────────────────────────────

  /// Deletes the song's file from the device and removes it everywhere.
  /// Returns false if the file couldn't be deleted.
  Future<bool> deleteSong(Song song) async {
    try {
      final file = File(song.path);
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (error) {
      debugPrint('Could not delete ${song.path}: $error');
      return false;
    }
    await dbService.deleteSongByPath(song.path);
    await _removeFromQueue(song.path);
    await _rebuildPlaylists(); // fresh counts
    _libraryRevision++;
    notifyListeners();
    return true;
  }

  /// Removes a song from the queue, keeping the current song selected. If the
  /// current song itself is removed, playback stops.
  Future<void> _removeFromQueue(String path) async {
    _originalSongList?.removeWhere((s) => s.path == path);
    final list = _currentSongList;
    if (list == null) return;
    final removedIndex = list.indexWhere((s) => s.path == path);
    if (removedIndex == -1) return;
    list.removeAt(removedIndex);

    final current = _currentSongIndex;
    if (current == null) return;
    if (removedIndex < current) {
      _currentSongIndex = current - 1;
    } else if (removedIndex == current) {
      _currentSongIndex = null;
      await audioHandler.stop();
      await _cleanupAlbumArt();
      await stateService?.saveCurrentSongPath(null);
    }
  }

  // ── Saving and restoring ──────────────────────────────────────────────────

  Future<void> _saveCurrentState() async {
    final state = stateService;
    if (state == null) return;
    try {
      await state.saveCurrentSongPath(currentSongPlaying?.path);
      await state.saveCurrentPlaylistPath(_queueFolderPath);
      await state.savePlaybackPosition(audioHandler.player.position.inMilliseconds);
    } catch (error) {
      debugPrint('Error saving playback state: $error');
    }
  }

  /// Reloads the last folder playlist and song, paused at the saved position.
  Future<void> _restorePlaybackState() async {
    final state = stateService;
    final songPath = state?.getCurrentSongPath();
    final folderPath = state?.getCurrentPlaylistPath();
    if (state == null || songPath == null || folderPath == null) return;
    if (!await Directory(folderPath).exists()) return;

    final songs = await loadFolderSongs(Directory(folderPath));
    final song = songs.where((s) => s.path == songPath).firstOrNull;
    if (song == null) return;

    _queueFolderPath = folderPath;
    _originalSongList = List<Song>.from(songs);
    _currentSongList = _isShuffle ? (List<Song>.from(songs)..shuffle()) : List<Song>.from(songs);
    _currentSongIndex = _currentSongList!.indexWhere((s) => s.path == songPath);
    final position = state.getPlaybackPosition();
    await _loadCurrentSong(
      autoplay: false,
      startAt: position != null ? Duration(milliseconds: position) : null,
    );
  }

  @override
  void dispose() {
    _stateSaveTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _cleanupAlbumArt();
    super.dispose();
  }
}
