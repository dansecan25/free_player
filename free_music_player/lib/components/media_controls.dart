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
              // Background: either image or solid color
              Container(
                decoration: BoxDecoration(
                  color: value.currentSongPlaying?.albumArtImagePathBytes == null
                      ? const Color.fromARGB(255, 168, 168, 168) // fallback color
                      : null,
                  image: value.currentSongPlaying?.albumArtImagePathBytes != null
                      ? DecorationImage(
                          image: MemoryImage(
                            value.currentSongPlaying!.albumArtImagePathBytes!,
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 30,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: value.currentSongPlaying != null
                                  ? value.currentSongPlaying!.songName.length > 25
                                      ? Marquee(
                                          text: value.currentSongPlaying!.songName,
                                          scrollAxis: Axis.horizontal,
                                          blankSpace: 20.0,
                                          velocity: 30.0,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          pauseAfterRound: Duration(seconds: 1),
                                        )
                                      : Text(
                                          value.currentSongPlaying!.songName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        )
                                  : const Text(
                                      "--------",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        // Arrow-up button
                        GestureDetector(
                          onTap: () {
                            if (value.currentSongPlaying != null) {
                              goToSong(value.currentSongPlaying!, context);
                            }
                          },
                          child: const Icon(
                            Icons.keyboard_arrow_up,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    // Song author row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            value.currentSongPlaying != null
                                ? value.currentSongPlaying!.artistName
                                : "------",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),
                    const SizedBox(height: 8),

                    // Playback Controls (unchanged)
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
              
            ],
          ),

        ),
      ),
    );
  }
}
