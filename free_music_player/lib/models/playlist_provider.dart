import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:audio_service/audio_service.dart';
import 'package:free_music_player/services/audio_handler.dart';
import 'package:free_music_player/services/playback_state_service.dart';
import 'package:id3/id3.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/services/database_service.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'dart:async';

class PlaylistProvider extends ChangeNotifier {
  final dbService = DatabaseService();
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
    notifyListeners();
  }
  

  PlaylistProvider(this.audioHandler, {this.stateService}) {
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
    _currentSongList = newList;
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

        // Restore playback state
        _currentSongList = playlist.playlistSongs;
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

    final index = _currentSongList!.indexWhere(
        (s) => s.songName == song.songName && s.artistName == song.artistName);
    if (index == -1) return;

    _currentSongList!.removeAt(index);
    // Also remove from the actual playlist object if needed
    final playlist = _playlists.firstWhere(
        (pl) => pl.playlistSongs == _currentSongList,
        orElse: () => throw Exception('Playlist not found'));
    playlist.playlistSongs!.removeAt(index);
    playlist.setSongCount(playlist.playlistSongs!.length);

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
      //sets the albums 
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
    setSongList();
    notifyListeners();
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

  Future<int> _countSongs(Directory dirPath)async{
    int counter = 0;
    List<FileSystemEntity> entities = dirPath.listSync();
    for (var entity in entities){
      if(_isMusicFile(entity)){
        counter++;
      }
    }
    return counter;
  }

  Future<List<Song>> setSongsForPlaylist(Directory path) async {
    List<Song> songs = [];
    List<FileSystemEntity> entities = path.listSync();

    for (var entity in entities) {
      if (_isMusicFile(entity)) {
        try {
          final metadata = readMetadata(File(entity.path), getImage: false);

          // Only pull the author
          String artistName = metadata.artist?.isNotEmpty == true
              ? metadata.artist!
              : "Unknown artist";

          // Pull album art
          Uint8List? albumArtBytes = await getImageUnit8(File(entity.path));

          Song songFile = Song(
            albumArtImagePathBytes: albumArtBytes,
            songName: (entity.path.split(Platform.pathSeparator).last)
              .replaceAll(RegExp(r'\.(mp3|flac)$', caseSensitive: false), ''),
            audioPath: entity,
            artistName: artistName,
          );

          songs.add(songFile);
        } catch (e) {
          print("Error reading metadata for ${entity.path}: $e");
        }
      }
    }

    return songs;
  }

  Future<Uint8List?> getImageUnit8(File filePath) async {
    List<int> mp3Bytes = filePath.readAsBytesSync();
    MP3Instance mp3instance = MP3Instance(mp3Bytes);

    if (mp3instance.parseTagsSync()) {
      var meta = mp3instance.getMetaTags();

      if (meta != null && meta.containsKey('APIC')) {
        var apic = meta['APIC'];
        if (apic != null && apic['base64'] != null) {
          String base64Image = apic['base64'];
          Uint8List imageBytes = base64Decode(base64Image);
          return imageBytes;
        }
      }
    }
    return null; // no album art
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

// Made with Bob
