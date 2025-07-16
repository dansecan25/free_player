import 'package:flutter/material.dart';
import 'package:free_music_player/components/neu_box.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

class MediaControls extends StatelessWidget {
  const MediaControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, value, child) => SafeArea(
        top: false, // Don't push it down from the top
        child: Container(
          color: const Color.fromARGB(255, 168, 168, 168),
          padding: const EdgeInsets.fromLTRB(10, 8,10,15),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Keep it small and at the bottom
            children: [
              // Song Title Row
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 35,
                      child: value.currentSongPlaying.songName.length > 25
                          ? Marquee(
                              text: value.currentSongPlaying.songName,
                              scrollAxis: Axis.horizontal,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              blankSpace: 20.0,
                              velocity: 30.0,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              pauseAfterRound: Duration(seconds: 1),
                              startPadding: 10.0,
                              accelerationDuration: Duration(seconds: 1),
                              accelerationCurve: Curves.linear,
                              decelerationDuration:
                                  Duration(milliseconds: 500),
                              decelerationCurve: Curves.easeOut,
                            )
                          : Text(
                              value.currentSongPlaying.songName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: value.previousSong,
                      child: const NeuBox(child: Icon(Icons.skip_previous)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: value.pauseOrResume,
                      child: NeuBox(
                        child: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: value.playNextSong,
                      child: const NeuBox(child: Icon(Icons.skip_next)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
