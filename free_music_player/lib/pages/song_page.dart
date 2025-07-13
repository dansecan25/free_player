import 'package:flutter/material.dart';
import 'package:free_music_player/components/neu_box.dart';
import 'package:free_music_player/models/song.dart';

class SongPage extends StatelessWidget {
  final Song songObject;
  const SongPage({super.key, required this.songObject});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(songObject.songName)),
      body: Column(children: [NeuBox(child: Icon(Icons.search, size: 200))]),
    );
  }
}
