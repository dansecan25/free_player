import 'package:flutter/material.dart';
import 'package:free_music_player/components/artwork_thumbnail.dart';
import 'package:free_music_player/components/player_controls.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

/// Mini player at the bottom of the list screens. Tap it to open the song page.
class MediaControls extends StatelessWidget {
  const MediaControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, player, _) {
        final song = player.currentSongPlaying;
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: song == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => SongPage(songObject: song)),
                            ),
                    child: Row(
                      children: [
                        if (song != null)
                          ArtworkThumbnail(song: song, size: 44)
                        else
                          const ArtworkImage(bytes: null, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 22,
                                child: ScrollingTitle(
                                  text: song?.songName ?? 'Nothing playing',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                song?.artistName ?? 'Pick a song to start',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_up, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                  PositionSlider(player: player),
                  const SizedBox(height: 4),
                  PlaybackButtons(player: player),
                ],
              ),
            ),
          ),
        );
      },
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
