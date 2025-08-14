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
                            child: Icon(Icons.music_note, size: 250),
                          ),
                          Padding(
                            padding: EdgeInsets.all(15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Wrap with Expanded to handle long titles
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      //Song title
                                      SizedBox(
                                        height: 25,
                                        child:
                                            value.currentSongPlaying!.songName.length > 25
                                                ? Marquee(
                                                  text: value.currentSongPlaying!.songName,
                                                  scrollAxis: Axis.horizontal,
                                                  blankSpace: 20.0,
                                                  velocity: 30.0,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  pauseAfterRound: Duration(
                                                    seconds: 1,
                                                  ),
                                                  startPadding: 10.0,
                                                  accelerationDuration:
                                                      Duration(seconds: 1),
                                                  accelerationCurve:
                                                      Curves.linear,
                                                  decelerationDuration:
                                                      Duration(
                                                        milliseconds: 500,
                                                      ),
                                                  decelerationCurve:
                                                      Curves.easeOut,
                                                )
                                                : Text(
                                                  value.currentSongPlaying!.songName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 20,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                      ),
                                      //Artist name
                                      Text(songObject.artistName),
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
                    const SizedBox(height: 25),
                    Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 25.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatTime(value.currentDuration)),

                              Icon(Icons.shuffle),

                              Icon(Icons.repeat),

                              Text(formatTime(value.totalDuration)),
                            ],
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 0,
                            ),
                          ),
                          child: Slider(
                            min: 0,
                            max: value.totalDuration.inSeconds.toDouble(),
                            value: value.currentDuration.inSeconds.toDouble(),
                            activeColor: const Color.fromARGB(255, 0, 103, 187),
                            onChanged: (double double) {},
                            onChangeEnd: (double double) {
                              value.seek(Duration(seconds: double.toInt()));
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: value.previousSong,
                            child: NeuBox(child: Icon(Icons.skip_previous)),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded( //play 
                          flex: 2,
                          child: GestureDetector(
                            onTap: value.pauseOrResume,
                            child: NeuBox(
                              child: Icon(
                                value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: GestureDetector(
                            onTap: value.playNextSong,
                            child: NeuBox(child: Icon(Icons.skip_next)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
