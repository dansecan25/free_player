import 'dart:io';
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

  PlaylistProvider() {
    initializeMusicDirectory();
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

  set currentSongIndex(int? newIndex) {
    _currentSongIndex = newIndex;

    notifyListeners();
  }
}
