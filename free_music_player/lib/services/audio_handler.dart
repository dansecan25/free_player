import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;
  PlaylistProvider? playlistProvider;
  bool _isInitialized = false;
  bool _isDisposing = false;

  AudioPlayerHandler() {
    _initializeAudioSession();
    _notifyAudioHandlerAboutPlaybackEvents();
  }

  /// Initialize audio session for background playback
  Future<void> _initializeAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      
      // Handle audio interruptions (phone calls, etc.)
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Lower volume during interruption
              _player.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Pause playback
              pause();
              break;
          }
        } else {
          // Interruption ended
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Restore volume
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              // Resume if we should
              if (event.type == AudioInterruptionType.pause) {
                play();
              }
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      // Handle audio becoming noisy (headphones unplugged)
      session.becomingNoisyEventStream.listen((_) {
        pause();
      });

      _isInitialized = true;
      print('Audio session initialized successfully');
    } catch (e) {
      print('Error initializing audio session: $e');
    }
  }

  void _notifyAudioHandlerAboutPlaybackEvents() {
    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        processingState: {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        speed: _player.speed,
      ));
    }, onError: (error) {
      print('Playback event stream error: $error');
    });
  }

  void setPlaylistProvider(PlaylistProvider playlistProvider){
    this.playlistProvider=playlistProvider;
  }

  /// Stop and clear current audio source before setting a new one
  Future<void> _clearCurrentSource() async {
    try {
      if (_player.playing) {
        await _player.stop();
      }
      // Small delay to ensure codec releases resources
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('Error clearing audio source: $e');
    }
  }

  Future<void> setAudioSource(AudioSource source) async {
    try {
      // Clear previous source to free codec resources
      await _clearCurrentSource();
      await _player.setAudioSource(source);
    } catch (e) {
      print('Error setting audio source: $e');
      rethrow;
    }
  }

  Future<void> setMediaItem(MediaItem item, {AudioSource? source}) async {
    try {
      if (source != null) {
        // Clear previous source to free codec resources
        await _clearCurrentSource();
        await _player.setAudioSource(source);
      }
      mediaItem.add(item); // updates Android/iOS notification & lockscreen
    } catch (e) {
      print('Error setting media item: $e');
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      print('Error playing: $e');
      // Attempt to recover by reloading the audio source
      if (playlistProvider != null && 
          playlistProvider!.currentSongPlaying != null) {
        try {
          await playlistProvider!.play();
        } catch (retryError) {
          print('Error retrying play: $retryError');
        }
      }
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      print('Error pausing: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      print('Error stopping: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print('Error seeking: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      await playlistProvider?.playNextSong();
    } catch (e) {
      print('Error skipping to next: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      await playlistProvider?.previousSong();
    } catch (e) {
      print('Error skipping to previous: $e');
    }
  }

  /// Dispose resources when handler is no longer needed
  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;
    
    try {
      await _player.stop();
      await _player.dispose();
    } catch (e) {
      print('Error disposing player: $e');
    }
  }

  /// Check if audio session is initialized
  bool get isInitialized => _isInitialized;
}

// Made with Bob
