import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:free_music_player/services/audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/services/database_service.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

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

  final AudioPlayerHandler audioHandler;
  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioPlayer get audioPlayer => _audioPlayer;

  Duration _currentDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;

  

  PlaylistProvider(this.audioHandler) {
    initializeMusicDirectory();
    _listenToDuration();
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
    notifyListeners();
  }

  Future<void> play() async {
    //final String path = _currentSongList![_currentSongIndex!].audioPath.path;
    final song = _currentSongList![_currentSongIndex!];
    final String path = song.audioPath.path;
    try {
      //await _audioPlayer.setFilePath(path);
      //await _audioPlayer.play();

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
        ),
      );


      await audioHandler.play();

    } catch (e) {
      print("Error playing song: $e");
    }
    notifyListeners();
  }

  Future<void> pause() async {
    await audioHandler.pause();
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
      this._totalDuration = player.duration ?? Duration.zero;
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
        List<Song> songs = await _setSongsForPlaylist(name, entity);
        playlists.add(Playlist(playlistName: name, playlistSongs: songs));
        _playlistNames.add(name);
        _playlistPaths.add(entity);
      }
    }
    notifyListeners();
  }

  Future<List<Song>> _setSongsForPlaylist(String name, Directory path) async {
    List<Song> songs = [];
    List<FileSystemEntity> entities = path.listSync();

    for (var entity in entities) {
      if (_isMusicFile(entity)) {
        try {
          final metadata = readMetadata(File(entity.path), getImage: false);
          
          // Only pull the author
          String artistName = "Unknown artist";
          
          artistName = metadata.artist?.isNotEmpty == true
              ? metadata.artist!
              : "Unknown artist";
            
          Song songFile = Song(
            albumArtImagePath: "none",
            songName: (entity.path.split(Platform.pathSeparator).last)
                .replaceAll('.mp3', ''),
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



  bool _isMusicFile(FileSystemEntity entity) {
    return entity is File && entity.path.endsWith('.mp3');
  }
}
