import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/components/neu_box.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';

class MediaControls extends StatelessWidget {
  const MediaControls({super.key});

  void goToSong(Song songObject, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SongPage(songObject: songObject)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (context, value, child) => SafeArea(
        top: false, // Don't push it down from the top
        child: GestureDetector(
          onTap: () {
            if (value.currentSongPlaying != null) {
              goToSong(value.currentSongPlaying!, context);
            }
          },
          child: Stack(
            children: [
              // Main container with song info & controls
              Container(
                color: const Color.fromARGB(255, 168, 168, 168),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 15),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Keep it small and at the bottom
                  children: [
                    // Song Title Row
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 30,
                            child: value.currentSongPlaying != null
                                ? value.currentSongPlaying!.songName.length > 25
                                    ? Marquee(
                                        text: value.currentSongPlaying!.songName,
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
                                        value.currentSongPlaying!.songName,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                : const Text(
                                    "--------",
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    // Song author row
                    Row(
                      children: [
                        Text(
                          value.currentSongPlaying != null
                              ? value.currentSongPlaying!.artistName
                              : "------",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
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
                          child: StreamBuilder<PlaybackState>(
                            stream: value.audioHandler.playbackState,
                            builder: (context, snapshot) {
                              final playing = snapshot.data?.playing ?? false;

                              return GestureDetector(
                                onTap: () => value.pauseOrResume(),
                                child: NeuBox(
                                  child: Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                  ),
                                ),
                              );
                            },
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

              // Arrow-up icon floating in top-right
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () {
                    if (value.currentSongPlaying != null) {
                      goToSong(value.currentSongPlaying!, context);
                    }
                  },
                  child: const Icon(
                    Icons.keyboard_arrow_up,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
