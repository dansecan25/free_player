import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/services/database_service.dart';
//import 'package:path/path.dart'; // Import for path manipulation

class PlaylistProvider extends ChangeNotifier {
  final dbService = DatabaseService();
  String _musicDirectoryPath = "";
  List<List<Song>> _songList = []; // Matrix of songs
  final List<String> _playlistNames = [];
  List<Playlist> _playlists = [];
  List<Directory> _playlistPaths = []; // Make this list of Directory type

  String get musicDirectoryPath => _musicDirectoryPath;
  List<List<Song>> get songList => _songList; // Returning a matrix of songs
  List<String> get playlistNames => _playlistNames;
  List<Playlist> get playlists => _playlists;

  int? _currentSongIndex;
  List<Song>? _currentSongList;

  //Audio controls
  final AudioPlayer _audioPlayer = AudioPlayer();

  //durations
  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;

  //constructor
  PlaylistProvider() {
    initializeMusicDirectory();
    listenToDuration();
  }

  //if not playing
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;
  Duration get currentDuration => _currentDuration;
  Duration get totalDuration => _totalDuration;
  Song get currentSongPlaying => _currentSongList![_currentSongIndex!];

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

    notifyListeners();
  }

  //play the song
  void play() async {
    final String path = _currentSongList![_currentSongIndex!].audioPath.path;
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
    _isPlaying = true;
    notifyListeners();
  }

  //pause song
  void pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
    notifyListeners();
  }

  //resume song
  void resume() async {
    await _audioPlayer.resume();
    _isPlaying = true;
    notifyListeners();
  }

  //pause or resume caller
  void pauseOrResume() async {
    if (_isPlaying) {
      pause();
    } else {
      resume();
    }
    notifyListeners();
  }

  //seek
  void seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  //play next song
  void playNextSong() {
    print("Current song index: ${_currentSongIndex}");
    if (_currentSongIndex != null) {
      if (_currentSongIndex! < _currentSongList!.length - 1) {
        _currentSongIndex = _currentSongIndex! + 1;
        play();
      } else {
        _currentSongIndex = 0;
      }
    }
    notifyListeners();
  }

  //previous song
  void previousSong() async {
    if (_currentDuration.inSeconds > 2) {
      seek(Duration.zero);
    } else {
      if (_currentSongIndex! > 0) {
        _currentSongIndex = _currentSongIndex! - 1;
      } else {
        _currentSongIndex = _currentSongList!.length - 1;
      }
    }
  }

  //duration listener
  void listenToDuration() {
    //tottal duration
    _audioPlayer.onDurationChanged.listen((newDuration) {
      _totalDuration = newDuration;
      notifyListeners();
    });
    //current duration
    _audioPlayer.onPositionChanged.listen((newPosition) {
      _currentDuration = newPosition;
      notifyListeners();
    });

    //listen for song completion
    _audioPlayer.onPlayerComplete.listen((event) {
      playNextSong();
    });
  }

  Future<void> initializeMusicDirectory() async {
    // Get stored path (or null)
    String? storedPath = await dbService.getMainFolderPath();

    if (storedPath != null && storedPath.isNotEmpty) {
      _musicDirectoryPath = storedPath;
      setSongList(); // or load your playlist logic
    }
    notifyListeners();
  }

  void setMusicDirectory(String path) {
    dbService.storeMainFolderPath(path);
    _musicDirectoryPath = path;
    setSongList(); // Refresh the song list
    notifyListeners(); // Notify listeners of directory change
  }

  void setSongList() async {
    if (_musicDirectoryPath.isEmpty) return;

    Directory musicDir = Directory(_musicDirectoryPath);
    if (!musicDir.existsSync()) {
      return;
    }

    _songList = []; //Cant use clear since the types is not valid
    _playlistNames.clear(); // Clear previous playlist names
    _playlistPaths = []; // cant also use clear for the same reason
    _playlists.clear();

    List<FileSystemEntity> entities = musicDir.listSync();

    for (var entity in entities) {
      if (entity is Directory) {
        // Add playlist name and path
        String name = entity.path.split(Platform.pathSeparator).last;
        List<Song> songs = _setSongsForPlaylist(name, entity);
        playlists.add(Playlist(playlistName: name, playlistSongs: songs));
        _playlistNames.add(entity.path.split(Platform.pathSeparator).last);
        _playlistPaths.add(entity);
      }
    }
    notifyListeners(); // Notify UI of changes
  }

  List<Song> _setSongsForPlaylist(String name, Directory path) {
    List<Song> songs = [];
    Directory playlistDir = path;
    List<FileSystemEntity> entities = playlistDir.listSync();
    for (var entity in entities) {
      Song songFile = Song(
        albumArtImagePath: "none",
        songName: (entity.path.split(Platform.pathSeparator).last).replaceAll(
          '.mp3',
          '',
        ),
        audioPath: entity,
        artistName: "Unknown artist",
      );
      songs.add(songFile);
    }
    return songs;
  }

  // Helper method to check if a file is a valid music file
  bool _isMusicFile(FileSystemEntity entity) {
    return entity is File && entity.path.endsWith('.mp3');
  }
}
