import 'package:flutter/material.dart';
import 'package:free_music_player/components/player_controls.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:free_music_player/utils/time_format.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

/// Mini player at the bottom of the list screens, with the current song's
/// artwork filling the background. Tap it to open the song page.
class MediaControls extends StatelessWidget {
  const MediaControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, player, _) {
        final song = player.currentSongPlaying;
        final artwork = player.currentArtwork;
        final scheme = Theme.of(context).colorScheme;
        final width = MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context);
        return Material(
          color: scheme.surfaceContainerHigh,
          child: Stack(
            children: [
              if (artwork != null)
                Positioned.fill(
                  child: Image.memory(
                    artwork,
                    fit: BoxFit.cover,
                    cacheWidth: width.round(),
                    gaplessPlayback: true,
                    // Corrupt artwork just leaves the plain background.
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: song == null
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => SongPage(songObject: song)),
                                ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _Chip(
                                    child: SizedBox(
                                      height: 24,
                                      child: ScrollingTitle(
                                        text: song?.songName ?? 'Nothing playing',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _Chip(
                                    child: Text(
                                      song?.artistName ?? 'Pick a song to start',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _Chip(
                              child: Icon(Icons.keyboard_arrow_up, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Chip(child: _time(player.currentDuration)),
                          _Chip(child: _time(player.totalDuration)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          inactiveTrackColor: Colors.grey.shade600,
                        ),
                        child: PositionSlider(player: player, showTimes: false),
                      ),
                      PlaybackButtons(player: player),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _time(Duration duration) =>
      Text(formatPlaybackTime(duration), style: const TextStyle(color: Colors.white));
}

/// Dark rounded label that keeps white text readable over any artwork.
class _Chip extends StatelessWidget {
  final Widget child;
  const _Chip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

/// Song title that scrolls when it's too long to fit, and stays still when
/// the system asks for reduced motion.
class ScrollingTitle extends StatelessWidget {
  final String text;
  final TextStyle style;

  const ScrollingTitle({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        if (fits || MediaQuery.disableAnimationsOf(context)) {
          return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
        }
        return Marquee(
          text: text,
          style: style,
          blankSpace: 32,
          velocity: 30,
          pauseAfterRound: const Duration(seconds: 1),
        );
      },
    );
  }
}
