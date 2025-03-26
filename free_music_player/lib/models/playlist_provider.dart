import 'dart:io';
import 'package:flutter/material.dart';
import 'package:free_music_player/models/song.dart';
import 'package:path/path.dart'; // Import for path manipulation

class PlaylistProvider extends ChangeNotifier {
  String _musicDirectoryPath = "";
  List<List<Song>> _songList = []; // Matrix of songs
  final List<String> _playlistNames = [];
  List<Directory> _playlistPaths = []; // Make this list of Directory type

  String get musicDirectoryPath => _musicDirectoryPath;
  List<List<Song>> get songList => _songList; // Returning a matrix of songs
  List<String> get playlistNames => _playlistNames;

  void setMusicDirectory(String path) {
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

    /*
    await for (var entity in musicDir.list(
      recursive: true,
      followLinks: false,
    )) {
      print(entity.path);
    }
    */

    List<FileSystemEntity> entities = musicDir.listSync();

    for (var entity in entities) {
      if (entity is Directory) {
        // Add playlist name and path
        _playlistNames.add(entity.path.split(Platform.pathSeparator).last);
        _playlistPaths.add(entity);
      }
    }
    print("Playlist Names: $_playlistNames");
    print("Playlist Paths: $_playlistPaths");

    // Now process each playlist path
    for (var playlistPath in _playlistPaths) {
      List<Song> playlistSongs = []; // List to hold songs for this playlist
      // Ensure we are working with a Directory and not a generic FileSystemEntity
      List<FileSystemEntity> playlistEntities = playlistPath.listSync();
      for (var entity in playlistEntities) {
        if (_isMusicFile(entity) && entity is File) {
          print(entity);
          String fileName = basename(entity.path);
          String songName = fileName.replaceAll(
            '.mp3',
            '',
          ); // Extract name from filename

          // Add song to the playlist's song list
          playlistSongs.add(
            Song(
              songName: songName,
              artistName: "Unknown Artist", // Placeholder for artist name
              albumArtImagePath:
                  "Not assigned yet", // Placeholder for album art
              audioPath: entity.path,
            ),
          );
        }
      }

      // Add the playlist songs list (matrix)
      _songList.add(playlistSongs);
    }
    print(_songList);
    notifyListeners(); // Notify UI of changes
  }

  // Helper method to check if a file is a valid music file
  bool _isMusicFile(FileSystemEntity entity) {
    return entity is File && entity.path.endsWith('.mp3');
  }
}
