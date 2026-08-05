import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:free_music_player/services/audio_handler.dart';
import 'package:free_music_player/services/playback_state_service.dart';
import 'package:free_music_player/services/song_sync_service.dart';
import 'package:id3/id3.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/models/song_record.dart';
import 'package:free_music_player/services/database_service.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show compute;

/// Lightweight, isolate-safe stand-in for a Song, used only to ferry
/// metadata scan results back from the background isolate spawned by
/// [compute]. Kept to primitive fields so it can be sent across the
/// isolate boundary cheaply.
class _SongMetadataStub {
  final String songName;
  final String artistName;
  final String audioPath;

  _SongMetadataStub(this.songName, this.artistName, this.audioPath);
}

bool _isMusicFilePath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp3') || lower.endsWith('.flac');
}

/// Runs entirely on a background isolate (via compute). Scans a playlist
/// directory and reads just the fast metadata (name/artist) for every song
/// -- no album art decoding here, which is what made this slow before.
List<_SongMetadataStub> _scanPlaylistMetadata(String dirPath) {
  final dir = Directory(dirPath);
  final entities = dir.listSync();
  final result = <_SongMetadataStub>[];

  for (final entity in entities) {
    if (entity is File && _isMusicFilePath(entity.path)) {
      try {
        final metadata = readMetadata(File(entity.path), getImage: false);
        final artistName = metadata.artist?.isNotEmpty == true
            ? metadata.artist!
            : "Unknown artist";
        final name = entity.path
            .split(Platform.pathSeparator)
            .last
            .replaceAll(RegExp(r'\.(mp3|flac)$', caseSensitive: false), '');
        result.add(_SongMetadataStub(name, artistName, entity.path));
      } catch (e) {
        // Skip unreadable files; the file is still counted elsewhere.
      }
    }
  }
  return result;
}

/// Runs entirely on a background isolate (via compute). Decodes embedded
/// album art for a batch of file paths. This is the expensive part
/// (full file read + tag parse per song) that used to block the UI thread.
Map<String, Uint8List?> _extractAlbumArtBatch(List<String> paths) {
  final result = <String, Uint8List?>{};
  for (final path in paths) {
    try {
      final mp3Bytes = File(path).readAsBytesSync();
      final mp3instance = MP3Instance(mp3Bytes);
      Uint8List? art;
      if (mp3instance.parseTagsSync()) {
        final meta = mp3instance.getMetaTags();
        if (meta != null && meta.containsKey('APIC')) {
          final apic = meta['APIC'];
          if (apic != null && apic['base64'] != null) {
            art = base64Decode(apic['base64']);
          }
        }
      }
      result[path] = art;
    } catch (e) {
      result[path] = null;
    }
  }
  return result;
}

class PlaylistProvider extends ChangeNotifier {
  final dbService = DatabaseService();
  late final SongSyncService _syncService;

  String _musicDirectoryPath = "";
  List<List<Song>> _songList = [];
  final List<String> _playlistNames = [];
  List<Playlist> _playlists = [];
  List<Directory> _playlistPaths = [];

  String get musicDirectoryPath => _musicDirectoryPath;
  List<List<Song>> get songList => _songList;
  List<String> get playlistNames => _playlistNames;
  List<Playlist> get playlists => _playlists;

  int? _currentSongIndex;
  List<Song>? _currentSongList;
  List<Song>? _originalSongList; // Store original order for unshuffling

  int? get currentIndex => _currentSongIndex;
  int get playlistLength => _currentSongList?.length ?? 0;

  final AudioPlayerHandler audioHandler;
  final PlaybackStateService? stateService;
  
  // Timer for periodic state saving
  Timer? _stateSaveTimer;
  
  // Track current album art file for cleanup
  File? _currentAlbumArtFile;

  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;

  //for repeat and shuffle values
  bool _isShuffle=false;
  int _isRepeat=0;

  bool get isShuffling => _isShuffle;
  int get isRepeating => _isRepeat;
  
  void repeat(){
    if(_isRepeat>=2){
      _isRepeat=0;
    }else{
      _isRepeat+=1;
    }
    stateService?.saveRepeatMode(_isRepeat);
    notifyListeners();
  }

  void shuffle(){
    _isShuffle=!_isShuffle;
    stateService?.saveShuffleState(_isShuffle);

    // _originalSongList always holds the canonical (unshuffled) order of
    // whatever queue is currently loaded -- it's kept up to date by the
    // currentSongList setter every time a new playlist/song is opened, so
    // it can never be left over from a *different* playlist the way it
    // used to be. That stale state was the root cause of shuffle breaking
    // after switching playlists.
    if (_originalSongList != null && _originalSongList!.isNotEmpty) {
      // Remember which song was playing so we can keep playback on it
      // after we rebuild the list.
      final currentSong = (_currentSongIndex != null &&
              _currentSongList != null &&
              _currentSongIndex! < _currentSongList!.length)
          ? _currentSongList![_currentSongIndex!]
          : null;

      if (_isShuffle) {
        // Always shuffle a fresh copy of the canonical order, never the
        // canonical list itself and never the list in place -- this keeps
        // the on-screen playlist order (which shares Song objects with
        // _originalSongList) untouched by shuffling the playback queue.
        _currentSongList = List<Song>.from(_originalSongList!)..shuffle();
      } else {
        _currentSongList = List<Song>.from(_originalSongList!);
      }

      if (currentSong != null) {
        final newIndex = _currentSongList!.indexWhere(
          (song) => song.audioPath.path == currentSong.audioPath.path,
        );
        _currentSongIndex = newIndex == -1 ? 0 : newIndex;
      }
    }

    notifyListeners();
  }
  

  PlaylistProvider(this.audioHandler, {this.stateService}) {
    _syncService = SongSyncService(dbService);
    initializeMusicDirectory();
    _listenToDuration();
    _restorePlaybackState();
    _startPeriodicStateSaving();
  }

  bool get isPlaying => audioHandler.playbackState.value.playing;

  Duration get currentDuration => _currentDuration;
  Duration get totalDuration => _totalDuration;

  Song? get currentSongPlaying =>
      _currentSongList != null && _currentSongIndex != null
          ? _currentSongList![_currentSongIndex!]
          : null;

  set currentSongList(List<Song>? newList) {
    if (newList == null) {
      _currentSongList = null;
      _originalSongList = null;
      return;
    }
    // Defensive copies: never hang on to the caller's actual list (e.g.
    // Playlist.playlistSongs / the list backing the on-screen SongListView).
    // Previously shuffle() called .shuffle() directly on this reference,
    // silently reordering the visible playlist too and leaving stale state
    // once a different playlist's list was assigned here.
    _originalSongList = List<Song>.from(newList);
    _currentSongList = _isShuffle
        ? (List<Song>.from(newList)..shuffle())
        : List<Song>.from(newList);
  }

  /// Starts playing [song] from [sourceList] (typically a playlist's song
  /// list). This is the safe way to begin playback of a playlist: it loads
  /// the list as the new queue (applying the current shuffle state, if any)
  /// and then locates [song] by identity within the resulting queue --
  /// rather than assuming a tapped index still lines up once shuffling may
  /// have reordered things.
  void playFromList(List<Song> sourceList, Song song) {
    currentSongList = sourceList;
    final index = _currentSongList!.indexWhere(
      (s) => s.audioPath.path == song.audioPath.path,
    );
    currentSongIndex = index == -1 ? 0 : index;
  }

  set currentSongIndex(int? newIndex) {
    _currentSongIndex = newIndex;
    if (newIndex != null &&
        _currentSongList != null &&
        _currentSongList!.isNotEmpty) {
      play();
    }
    stateService?.saveCurrentSongIndex(newIndex);
    notifyListeners();
  }

  void setSongPlaying(Song songObject, int songIndex){
    // This method can be used for additional logic if needed
  }

  /// Restore playback state from saved preferences
  Future<void> _restorePlaybackState() async {
    if (stateService == null || !stateService!.hasSavedState()) {
      return;
    }

    try {
      // Restore shuffle and repeat states
      _isShuffle = stateService!.getShuffleState();
      _isRepeat = stateService!.getRepeatMode();

      final savedIndex = stateService!.getCurrentSongIndex();
      final savedPlaylistPath = stateService!.getCurrentPlaylistPath();
      final savedPosition = stateService!.getPlaybackPosition();

      if (savedIndex != null && savedPlaylistPath != null) {
        // Find the playlist by path
        final playlist = _playlists.firstWhere(
          (pl) => pl.directoryPath.path == savedPlaylistPath,
          orElse: () => _playlists.first,
        );

        // Load songs if not already loaded
        if (playlist.playlistSongs == null || playlist.playlistSongs!.isEmpty) {
          final songs = await setSongsForPlaylist(playlist.directoryPath);
          playlist.setSongs(songs);
        }

        // Restore playback state (defensive copy -- see currentSongList setter)
        _originalSongList = List<Song>.from(playlist.playlistSongs!);
        _currentSongList = List<Song>.from(playlist.playlistSongs!);
        _currentSongIndex = savedIndex;

        if (_currentSongList != null && 
            savedIndex < _currentSongList!.length) {
          // Restore the song but don't auto-play
          await play();
          
          // Seek to saved position if available
          if (savedPosition != null) {
            await seek(Duration(milliseconds: savedPosition));
          }
          
          // Pause immediately (user can resume manually)
          await pause();
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error restoring playback state: $e');
    }
  }

  /// Start periodic state saving
  void _startPeriodicStateSaving() {
    _stateSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveCurrentState();
    });
  }

  /// Save current playback state
  Future<void> _saveCurrentState() async {
    if (stateService == null) return;

    try {
      await stateService!.saveCurrentSongIndex(_currentSongIndex);
      
      if (_currentSongList != null && _currentSongList!.isNotEmpty) {
        // Save the playlist directory path
        final currentPlaylist = _playlists.firstWhere(
          (pl) => pl.playlistSongs == _currentSongList,
          orElse: () => _playlists.first,
        );
        await stateService!.saveCurrentPlaylistPath(currentPlaylist.directoryPath.path);
      }

      // Save current position
      final position = audioHandler.player.position;
      await stateService!.savePlaybackPosition(position.inMilliseconds);
    } catch (e) {
      print('Error saving state: $e');
    }
  }

  /// Clean up previous album art file
  Future<void> _cleanupAlbumArt() async {
    if (_currentAlbumArtFile != null) {
      try {
        if (await _currentAlbumArtFile!.exists()) {
          await _currentAlbumArtFile!.delete();
        }
      } catch (e) {
        print('Error deleting album art file: $e');
      }
      _currentAlbumArtFile = null;
    }
  }

  Future<void> play() async {
    final song = _currentSongList![_currentSongIndex!];
    final String path = song.audioPath.path;
    try {
      // Clean up previous album art file
      await _cleanupAlbumArt();
      
      String? artUriPath;
      // Save album art to a temporary file if it exists
      if (song.albumArtImagePathBytes != null) {
        final tempDir = await getTemporaryDirectory();
        // Use a unique filename to avoid conflicts
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${tempDir.path}/album_art_$timestamp.jpg');
        await file.writeAsBytes(song.albumArtImagePathBytes!);
        artUriPath = file.path;
        _currentAlbumArtFile = file; // Track for cleanup
      }
      
      // Update audio_service metadata
      // Set the MediaItem and audio source
      await audioHandler.setMediaItem(
        MediaItem(
          id: path,
          title: song.songName,
          artist: song.artistName,
          album: "Unknown Album",
          duration: await audioHandler.player.setAudioSource(
            AudioSource.uri(Uri.file(path))
          ).then((_) => audioHandler.player.duration ?? Duration.zero),
          artUri: artUriPath != null ? Uri.file(artUriPath) : null,
        ),
      );

      await audioHandler.play();
      
      // Save state after starting playback
      await _saveCurrentState();

    } catch (e) {
      print("Error playing song: $e");
      // Clean up on error
      await _cleanupAlbumArt();
    }
    notifyListeners();
  }

  Future<void> deleteSong(BuildContext context, Song songObject, int songIndex) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Song"),
        content: Text("Are you sure you want to delete \"${songObject.songName}\" permanently from device?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

  if (confirm == true) {
    try {
      final file = File(songObject.audioPath.path);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from SONGS table
      await dbService.deleteSongByPath(songObject.audioPath.path);

      // Remove song from current playlist in memory and update count
      for (var playlist in _playlists) {
        final initialLength = playlist.playlistSongs?.length ?? 0;
        playlist.playlistSongs?.removeWhere(
          (song) => song.audioPath.path == songObject.audioPath.path,
        );
        // Update cached song count
        final newLength = playlist.playlistSongs?.length ?? 0;
        if (initialLength != newLength) {
          playlist.setSongCount(newLength);
        }
      }

      // Also remove from current view (if applicable)
      _currentSongList?.removeWhere(
        (song) => song.audioPath.path == songObject.audioPath.path,
      );
      _originalSongList?.removeWhere(
        (song) => song.audioPath.path == songObject.audioPath.path,
      );

      notifyListeners(); // UI rebuilds automatically

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deleted ${songObject.songName}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting song: $e")),
      );
    }
  }
}

  Future<void> deleteCurrentSong(BuildContext context, Song song) async {
    if (_currentSongList == null) return;

    _currentSongList!.removeWhere(
        (s) => s.audioPath.path == song.audioPath.path);
    _originalSongList?.removeWhere(
        (s) => s.audioPath.path == song.audioPath.path);

    // Also remove from whichever playlist actually contains this song
    // (matched by identity, since _currentSongList is now always a
    // defensive copy rather than the same list object as a playlist's
    // playlistSongs).
    for (final playlist in _playlists) {
      final removed = playlist.playlistSongs
              ?.where((s) => s.audioPath.path == song.audioPath.path)
              .isNotEmpty ??
          false;
      if (removed) {
        playlist.playlistSongs!
            .removeWhere((s) => s.audioPath.path == song.audioPath.path);
        playlist.setSongCount(playlist.playlistSongs!.length);
        break;
      }
    }

    // Remove from DB
    await dbService.deleteSongByPath(song.audioPath.path);

    // notify listeners to update UI
    notifyListeners();
  }


  Future<void> pause() async {
    await audioHandler.pause();
    await _saveCurrentState();
    notifyListeners();
  }

  Future<void> resume() async {
    await audioHandler.play();
    notifyListeners();
  }

  Future<void> pauseOrResume() async {
    if (audioHandler.playbackState.value.playing) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
    notifyListeners(); // so UI rebuilds immediately
  }

  Future<void> seek(Duration position) async {
    await audioHandler.seek(position);
  }

  Future<void> playNextSong() async {
    if (_currentSongIndex != null) {
      if (_currentSongIndex! < _currentSongList!.length - 1) {
        _currentSongIndex = _currentSongIndex! + 1;
      } else {
        _currentSongIndex = 0;
      }
      await play();
    }
    notifyListeners();
  }

  Future<void> previousSong() async {
    if (_currentDuration.inSeconds > 5) {
      await seek(Duration.zero);
    } else {
      if (_currentSongIndex! > 0) {
        _currentSongIndex = _currentSongIndex! - 1;
      } else {
        _currentSongIndex = _currentSongList!.length - 1;
      }
      await play();
    }
  }

  void _listenToDuration() {
    final player = audioHandler.player; 

    // Total duration
    player.durationStream.listen((newDuration) {
      _totalDuration = player.duration ?? Duration.zero;
      notifyListeners();
    });

    // Current position
    player.positionStream.listen((newPosition) {
      _currentDuration = newPosition;
      notifyListeners();
    });

    // Listen to end of song
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_currentSongList == null || _currentSongIndex == null) return;

        if (isRepeating > 0) {
          if (isRepeating == 1) {
            // repeat all
            playNextSong();
          } else if (isRepeating == 2) {
            // repeat one
            play(); // play the same song again
          }
        } else {
          // No repeat
          if (currentIndex! + 1 <playlistLength) {
            playNextSong(); // only advance if not at the last song
          } 
        }
      }
    });

  }

  Future<void> initializeMusicDirectory() async {
    String? storedPath = await dbService.getMainFolderPath();

    if (storedPath != null && storedPath.isNotEmpty) {
      _musicDirectoryPath = storedPath;
      // Sync library first, then build playlists
      await _syncService.syncLibrary(Directory(storedPath));
      setSongList();
    }
    notifyListeners();
  }

  Future<int> countSongs(Directory dirPath) async {
    return await _countSongs(dirPath);
  }


  void setMusicDirectory(String path) {
    dbService.storeMainFolderPath(path);
    _musicDirectoryPath = path;
    // Sync library before building playlists
    _syncService.syncLibrary(Directory(path)).then((_) {
      setSongList();
      notifyListeners();
    });
  }

  void setSongList() async {
    if (_musicDirectoryPath.isEmpty) return;

    Directory musicDir = Directory(_musicDirectoryPath);
    
    if (!musicDir.existsSync()) return;

    _songList = [];
    _playlistNames.clear();
    _playlistPaths = [];
    _playlists.clear();

    List<FileSystemEntity> entities = musicDir.listSync();

    for (var entity in entities) {
      print("Entity is: ");
      print(entity);
      if (entity is Directory) {
        String name = entity.path.split(Platform.pathSeparator).last;
        // Count songs and cache the count
        final count = await _countSongs(entity);
        playlists.add(Playlist(
          playlistName: name, 
          playlistSongs: null, 
          directoryPath: entity,
          songCount: count, // Cache the count immediately
        ));
        _playlistNames.add(name);
        _playlistPaths.add(entity);
      }
    }
    notifyListeners();
  }

  Future<int> _countSongs(Directory dirPath) async {
    int counter = 0;
    List<FileSystemEntity> entities = dirPath.listSync();
    for (var entity in entities){
      if(_isMusicFile(entity)){
        counter++;
      }
    }
    return counter;
  }

  /// Loads songs for a playlist from a single DB query.
  ///
  /// Phase 1 (sync, fast): one SQL query fetches all rows whose
  /// folder_locations contains [path]. Each song gets its compressed
  /// thumbnail_small immediately, so the list shows thumbnails on first
  /// render with zero extra I/O.
  ///
  /// Phase 2 (async, fire-and-forget): songs whose thumbnail_small is still
  /// null (brand-new additions since last sync) get their art decoded from
  /// the file on a background isolate and written back to DB.
  Future<List<Song>> setSongsForPlaylist(
    Directory path, {
    void Function(List<Song> updatedBatch)? onArtworkBatchLoaded,
  }) async {
    // ── Phase 1: single DB query — O(1) regardless of playlist size ──────
    final records = await dbService.getSongsForFolder(path.path);

    // Fall back to file scan only when the folder has no DB entries yet
    // (first run before sync has completed).
    if (records.isEmpty) {
      return _setSongsForPlaylistFallback(path,
          onArtworkBatchLoaded: onArtworkBatchLoaded);
    }

    final songs = records
        .map((r) => Song(
              songName: r.title,
              artistName: r.author,
              // Use compressed thumbnail for list display
              albumArtImagePathBytes: r.thumbnailSmall ?? r.thumbnailData,
              audioPath: File(r.path),
            ))
        .toList();

    // ── Phase 2: back-fill art for any rows still missing it ─────────────
    final pathsNeedingArt = records
        .where((r) => r.thumbnailSmall == null && r.thumbnailData == null)
        .map((r) => r.path)
        .toList();

    if (pathsNeedingArt.isNotEmpty) {
      _loadAlbumArtInBackground(
        songs,
        pathFilter: pathsNeedingArt.toSet(),
        onBatchLoaded: onArtworkBatchLoaded,
        persistToDb: true,
      );
    }

    return songs;
  }

  /// Fallback used on the very first open (before sync has run).
  /// Scans the directory on a background isolate and populates the DB.
  Future<List<Song>> _setSongsForPlaylistFallback(
    Directory path, {
    void Function(List<Song> updatedBatch)? onArtworkBatchLoaded,
  }) async {
    final stubs = await compute(_scanPlaylistMetadata, path.path);
    final songs = stubs
        .map((s) => Song(
              songName: s.songName,
              artistName: s.artistName,
              albumArtImagePathBytes: null,
              audioPath: File(s.audioPath),
            ))
        .toList();
    _loadAlbumArtInBackground(
      songs,
      onBatchLoaded: onArtworkBatchLoaded,
      persistToDb: true,
    );
    return songs;
  }

  /// Decodes album art for songs that still need it, in batches on a
  /// background isolate, updating each Song's notifier in-place.
  /// When [persistToDb] is true, also compresses and writes back to DB.
  Future<void> _loadAlbumArtInBackground(
    List<Song> songs, {
    Set<String>? pathFilter,
    void Function(List<Song> batch)? onBatchLoaded,
    bool persistToDb = false,
  }) async {
    const batchSize = 10;

    final targetSongs = pathFilter != null
        ? songs.where((s) => pathFilter.contains(s.audioPath.path)).toList()
        : songs;

    for (int i = 0; i < targetSongs.length; i += batchSize) {
      final end = (i + batchSize < targetSongs.length)
          ? i + batchSize
          : targetSongs.length;
      final batch = targetSongs.sublist(i, end);
      final paths = batch.map((s) => s.audioPath.path).toList();

      try {
        final artByPath = await compute(_extractAlbumArtBatch, paths);
        for (final song in batch) {
          final art = artByPath[song.audioPath.path];
          song.albumArtImagePathBytes = art;

          if (persistToDb && art != null) {
            final existing = await dbService.getSongByPath(song.audioPath.path);
            if (existing != null) {
              if (existing.thumbnailData == null) {
                await dbService.upsertSong(existing.copyWith(thumbnailData: art));
              }
              if (existing.thumbnailSmall == null) {
                final small = await _SongSyncCompressor.compress(art);
                if (small != null) {
                  await dbService.updateThumbnailSmall(song.audioPath.path, small);
                }
              }
            } else {
              final small = await _SongSyncCompressor.compress(art);
              await dbService.upsertSong(
                _SongRecordHelper.fromSong(song, art, small),
              );
            }
          }
        }
        if (onBatchLoaded != null) {
          onBatchLoaded(batch);
        } else {
          notifyListeners();
        }
      } catch (e) {
        print('Error loading album art batch: $e');
      }
    }
  }



  bool _isMusicFile(FileSystemEntity entity) {
    return entity is File &&
        (entity.path.toLowerCase().endsWith('.mp3') ||
        entity.path.toLowerCase().endsWith('.flac'));
  }

  @override
  void dispose() {
    _stateSaveTimer?.cancel();
    // Clean up album art file on dispose
    _cleanupAlbumArt();
    super.dispose();
  }

}

// ── Internal helpers ──────────────────────────────────────────────────────────

extension _SongRecordCopy on SongRecord {
  SongRecord copyWith({
    int? id,
    String? title,
    String? author,
    String? album,
    String? path,
    List<String>? folderLocations,
    List<String>? playlists,
    Uint8List? thumbnailData,
    Uint8List? thumbnailSmall,
  }) {
    return SongRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      album: album ?? this.album,
      path: path ?? this.path,
      folderLocations: folderLocations ?? this.folderLocations,
      playlists: playlists ?? this.playlists,
      thumbnailData: thumbnailData ?? this.thumbnailData,
      thumbnailSmall: thumbnailSmall ?? this.thumbnailSmall,
    );
  }
}

class _SongRecordHelper {
  static SongRecord fromSong(Song song, Uint8List? art, Uint8List? small) {
    return SongRecord(
      title: song.songName,
      author: song.artistName,
      path: song.audioPath.path,
      folderLocations: [song.audioPath.parent.path],
      thumbnailData: art,
      thumbnailSmall: small,
    );
  }
}

/// Thin wrapper so [PlaylistProvider] can call compression without importing
/// song_sync_service directly.
class _SongSyncCompressor {
  static Future<Uint8List?> compress(Uint8List art) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        art,
        minWidth: 96,
        minHeight: 96,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      return result.length < art.length ? result : art;
    } catch (_) {
      return null;
    }
  }
}
