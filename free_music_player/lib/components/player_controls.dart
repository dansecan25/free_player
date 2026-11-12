import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/components/neu_box.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/utils/time_format.dart';

/// Seek bar. The value is clamped because the position can briefly run past
/// the duration (or the duration is still unknown), which Slider rejects.
class PositionSlider extends StatelessWidget {
  final PlaylistProvider player;
  final bool showTimes;

  const PositionSlider({super.key, required this.player, this.showTimes = true});

  @override
  Widget build(BuildContext context) {
    final max = player.totalDuration.inMilliseconds.toDouble();
    final value = player.currentDuration.inMilliseconds.toDouble().clamp(0.0, max);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          min: 0,
          max: max > 0 ? max : 1,
          value: max > 0 ? value : 0,
          onChanged: max > 0
              ? (ms) => player.seek(Duration(milliseconds: ms.round()))
              : null,
        ),
        if (showTimes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatPlaybackTime(player.currentDuration)),
                Text(formatPlaybackTime(player.totalDuration)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Previous, play/pause and next buttons.
class PlaybackButtons extends StatelessWidget {
  final PlaylistProvider player;
  const PlaybackButtons({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ControlButton(
            icon: Icons.skip_previous,
            label: 'Previous song',
            onTap: player.previousSong,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: StreamBuilder<PlaybackState>(
            stream: player.audioHandler.playbackState,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return _ControlButton(
                icon: playing ? Icons.pause : Icons.play_arrow,
                label: playing ? 'Pause' : 'Play',
                onTap: player.pauseOrResume,
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ControlButton(
            icon: Icons.skip_next,
            label: 'Next song',
            onTap: player.playNextSong,
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: NeuBox(
          child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
