import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/components/neu_box.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:provider/provider.dart';
import 'package:marquee/marquee.dart';

class SongPage extends StatelessWidget {
  final Song songObject;
  const SongPage({super.key, required this.songObject});

  String formatTime(Duration duration) {
    String twoDigitSeconds = duration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    String formattedTime = "${duration.inMinutes}:$twoDigitSeconds";

    return formattedTime;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder:
          (context, value, child) => Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            //body: Column(children: [NeuBox(child: Icon(Icons.search, size: 200))]),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 25, right: 25, bottom: 25),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    //App bar on the top
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back),
                        ),

                        // THIS is the key fix: Expanded handles the width safely
                        Expanded(
                          child: SizedBox(
                            height: 25, // enough height for Marquee
                            child:
                                value.currentSongPlaying!.songName.length > 25
                                    ? Marquee(
                                      text: value.currentSongPlaying!.songName,
                                      scrollAxis: Axis.horizontal,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      blankSpace: 20.0,
                                      velocity: 30.0,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      pauseAfterRound: Duration(seconds: 1),
                                      startPadding: 10.0,
                                      accelerationDuration: Duration(
                                        seconds: 1,
                                      ),
                                      accelerationCurve: Curves.linear,
                                      decelerationDuration: Duration(
                                        milliseconds: 500,
                                      ),
                                      decelerationCurve: Curves.easeOut,
                                    )
                                    : Text(
                                      value.currentSongPlaying!.songName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),

                        IconButton(onPressed: () {}, icon: Icon(Icons.menu)),
                      ],
                    ),

                    const SizedBox(height: 25),
                    //Song art
                    NeuBox(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: value.currentSongPlaying?.albumArtImagePathBytes != null
                                ? Image.memory(
                                    value.currentSongPlaying!.albumArtImagePathBytes!,
                                    width: 250,
                                    height: 250,
                                    fit: BoxFit.cover,
                                  )
                                : Icon(
                                    Icons.music_note,
                                    size: 250,
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Song title
                                      SizedBox(
                                        height: 25,
                                        child: value.currentSongPlaying!.songName.length > 25
                                            ? Marquee(
                                                text: value.currentSongPlaying!.songName,
                                                scrollAxis: Axis.horizontal,
                                                blankSpace: 20.0,
                                                velocity: 30.0,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                pauseAfterRound: const Duration(seconds: 1),
                                                startPadding: 10.0,
                                                accelerationDuration: const Duration(seconds: 1),
                                                accelerationCurve: Curves.linear,
                                                decelerationDuration:
                                                    const Duration(milliseconds: 500),
                                                decelerationCurve: Curves.easeOut,
                                              )
                                            : Text(
                                                value.currentSongPlaying!.songName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                      ),
                                      // Artist name
                                      Text(value.currentSongPlaying!.artistName),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    //NeuBox(child: Image.asset("png path")),
                    const SizedBox(height: 25),//below, the slider and timestamps
                    Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 25.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Current position
                                Text(formatTime(value.currentDuration)),

                                Icon(Icons.shuffle),
                                Icon(Icons.repeat),

                                // Total duration
                                // Total duration text
                                Text(formatTime(value.totalDuration))
                              ],
                            ),
                          ),
                          // Slider
                          Slider(
                              min: 0,
                              max: value.totalDuration.inSeconds.toDouble(),
                              value: value.currentDuration.inSeconds.toDouble(),
                              onChanged: (s) => value.seek(Duration(seconds: s.toInt())),
                            )
                          ],
                      ),

                    const SizedBox(height: 10),//below, play pause skip rewind buttons
                    Row(
                      children: [
                        // Previous song button
                        Expanded(
                          child: GestureDetector(
                            onTap: value.previousSong,
                            child: NeuBox(child: Icon(Icons.skip_previous)),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Play / Pause button
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
                        const SizedBox(width: 20),

                        // Next song button
                        Expanded(
                          child: GestureDetector(
                            onTap: value.playNextSong,
                            child: NeuBox(child: Icon(Icons.skip_next)),
                          ),
                        ),
                      ],
                    )

                    ],
                ),
              ),
            ),
          ),
    );
  }
}
