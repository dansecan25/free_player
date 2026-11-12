import 'package:flutter/material.dart';
import 'package:free_music_player/components/library_reload_mixin.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:free_music_player/components/song_list_skeleton.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:free_music_player/pages/songlist_view.dart';
import 'package:provider/provider.dart';

/// Every song in the music folder.
class AllSongsPage extends StatefulWidget {
  const AllSongsPage({super.key});

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage> with LibraryReloadMixin {
  List<Song>? _songs;

  @override
  void initState() {
    super.initState();
    reloadSongs();
  }

  @override
  Future<void> reloadSongs() async {
    final records = await context.read<PlaylistProvider>().dbService.getAllSongs();
    if (mounted) setState(() => _songs = records.map(songFromRecord).toList());
  }

  void _play(Song song, List<Song> queue) {
    context.read<PlaylistProvider>().playFromList(queue, song);
    Navigator.push(context, MaterialPageRoute(builder: (_) => SongPage(songObject: song)));
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    return Scaffold(
      appBar: AppBar(title: const Text('All songs')),
      body: songs == null
          ? const SongListSkeleton()
          : SongListView(
              songs: songs,
              onSongTap: _play,
              onRefresh: refreshFromDisk,
              emptyMessage: 'No songs yet.\nChoose your music folder in Settings.',
            ),
      bottomNavigationBar: const MediaControls(),
    );
  }
}
