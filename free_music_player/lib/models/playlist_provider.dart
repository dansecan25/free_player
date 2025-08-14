import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/services/database_service.dart';

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

  final AudioHandler audioHandler;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;

  

  PlaylistProvider(this.audioHandler) {
    initializeMusicDirectory();
    _listenToDuration();
  }

  bool get isPlaying => _audioPlayer.playerState.playing;

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
    notifyListeners();
  }

  Future<void> play() async {
    final String path = _currentSongList![_currentSongIndex!].audioPath.path;
    try {
      await _audioPlayer.setFilePath(path);
      await _audioPlayer.play();

      // Update audio_service metadata
      final song = _currentSongList![_currentSongIndex!];
      audioHandler.playMediaItem(
        MediaItem(
          id: song.audioPath.path,
          title: song.songName,
          artist: song.artistName,
          album: "Unknown Album",
          duration: _audioPlayer.duration,
        ),
      );

    } catch (e) {
      print("Error playing song: $e");
    }
    notifyListeners();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
    notifyListeners();
  }

  Future<void> pauseOrResume() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    notifyListeners(); // so UI rebuilds immediately
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
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
    _audioPlayer.durationStream.listen((newDuration) {
      if (newDuration != null) {
        _totalDuration = newDuration;
        notifyListeners();
      }
    });

    _audioPlayer.positionStream.listen((newPosition) {
      _currentDuration = newPosition;
      notifyListeners();
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        playNextSong();
      }
    });
  }

  Future<void> initializeMusicDirectory() async {
    String? storedPath = await dbService.getMainFolderPath();

    if (storedPath != null && storedPath.isNotEmpty) {
      _musicDirectoryPath = storedPath;
      setSongList();
    }
    notifyListeners();
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
      if (entity is Directory) {
        String name = entity.path.split(Platform.pathSeparator).last;
        List<Song> songs = _setSongsForPlaylist(name, entity);
        playlists.add(Playlist(playlistName: name, playlistSongs: songs));
        _playlistNames.add(name);
        _playlistPaths.add(entity);
      }
    }
    notifyListeners();
  }

  List<Song> _setSongsForPlaylist(String name, Directory path) {
    List<Song> songs = [];
    List<FileSystemEntity> entities = path.listSync();
    for (var entity in entities) {
      if (_isMusicFile(entity)) {
        Song songFile = Song(
          albumArtImagePath: "none",
          songName: (entity.path.split(Platform.pathSeparator).last)
              .replaceAll('.mp3', ''),
          audioPath: entity,
          artistName: "Unknown artist",
        );
        songs.add(songFile);
      }
    }
    return songs;
  }

  bool _isMusicFile(FileSystemEntity entity) {
    return entity is File && entity.path.endsWith('.mp3');
  }
}
