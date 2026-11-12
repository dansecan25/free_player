import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:free_music_player/components/artwork_thumbnail.dart';
import 'package:free_music_player/components/media_controls.dart' show ScrollingTitle;
import 'package:free_music_player/components/player_controls.dart';
import 'package:free_music_player/components/song_actions.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:provider/provider.dart';

/// Full-screen player with the full-size artwork.
class SongPage extends StatefulWidget {
  final Song songObject;
  const SongPage({super.key, required this.songObject});

  @override
  State<SongPage> createState() => _SongPageState();
}

class _SongPageState extends State<SongPage> {
  // The full artwork is loaded once per song, not on every position update.
  String? _artworkPath;
  Future<Uint8List?>? _artwork;

  Future<Uint8List?> _artworkFor(PlaylistProvider player, Song song) {
    if (_artworkPath != song.path) {
      _artworkPath = song.path;
      _artwork = player.dbService
          .getFullArtwork(song.path)
          .then((bytes) => bytes ?? song.albumArtImagePathBytes);
    }
    return _artwork!;
  }

  Future<void> _delete(Song song) async {
    final deleted = await confirmAndDeleteSong(context, song);
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlaylistProvider>();
    final song = player.currentSongPlaying ?? widget.songObject;
    final scheme = Theme.of(context).colorScheme;
    final activeColor = scheme.primary;
    final idleColor = scheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now playing'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Song options',
            onSelected: (_) => _delete(song),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: const Text('Delete from device'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final artSize = (constraints.maxWidth - 48).clamp(120.0, 420.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  FutureBuilder<Uint8List?>(
                    future: _artworkFor(player, song),
                    builder: (context, snapshot) => ArtworkImage(
                      bytes: snapshot.data ?? song.albumArtImagePathBytes,
                      size: artSize,
                      radius: 24,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 30,
                    child: ScrollingTitle(
                      text: song.songName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      song.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PositionSlider(player: player),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: player.isShuffling ? 'Shuffle on' : 'Shuffle off',
                        icon: Icon(Icons.shuffle,
                            color: player.isShuffling ? activeColor : idleColor),
                        onPressed: player.shuffle,
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        tooltip: const ['Repeat off', 'Repeat all', 'Repeat one'][player.isRepeating],
                        icon: Icon(
                          player.isRepeating == 2 ? Icons.repeat_one : Icons.repeat,
                          color: player.isRepeating > 0 ? activeColor : idleColor,
                        ),
                        onPressed: player.repeat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  PlaybackButtons(player: player),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
