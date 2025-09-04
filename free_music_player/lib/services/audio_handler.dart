import 'package:audio_service/audio_service.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;
  PlaylistProvider? playlistProvider;

  AudioPlayerHandler() {
    _notifyAudioHandlerAboutPlaybackEvents();
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
    });
  }

  void setPlaylistProvider(PlaylistProvider playlistProvider){
    this.playlistProvider=playlistProvider;
  }

  Future<void> setAudioSource(AudioSource source) async {
    await _player.setAudioSource(source);
  }

  Future<void> setMediaItem(MediaItem item, {AudioSource? source}) async {
    if (source != null) {
      await _player.setAudioSource(source);
    }
    mediaItem.add(item); // updates Android/iOS notification & lockscreen
  }

  @override
  Future<void> play() {
    print("Play button pressed from notification");
    return _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    await playlistProvider?.playNextSong();
  }

  @override
  Future<void> skipToPrevious() async {
    await playlistProvider?.previousSong();
  }
}
