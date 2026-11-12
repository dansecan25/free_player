import 'package:flutter/material.dart';
import 'package:free_music_player/components/library_reload_mixin.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:free_music_player/components/song_list_skeleton.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:free_music_player/pages/songlist_view.dart';
import 'package:provider/provider.dart';

/// Songs in a folder playlist.
class PlaylistSongsPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistSongsPage({super.key, required this.playlist});

  @override
  State<PlaylistSongsPage> createState() => _PlaylistSongsPageState();
}

class _PlaylistSongsPageState extends State<PlaylistSongsPage> with LibraryReloadMixin {
  List<Song>? _songs;

  @override
  void initState() {
    super.initState();
    _songs = widget.playlist.playlistSongs;
    reloadSongs();
  }

  @override
  Future<void> reloadSongs() async {
    final songs = await context
        .read<PlaylistProvider>()
        .loadFolderSongs(widget.playlist.directoryPath);
    widget.playlist.setSongs(songs);
    if (mounted) setState(() => _songs = songs);
  }

  void _play(Song song, List<Song> queue) {
    context.read<PlaylistProvider>().playFromList(
          queue,
          song,
          folderPath: widget.playlist.directoryPath.path,
        );
    Navigator.push(context, MaterialPageRoute(builder: (_) => SongPage(songObject: song)));
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.playlistName)),
      body: songs == null
          ? const SongListSkeleton()
          : SongListView(
              songs: songs,
              onSongTap: _play,
              onRefresh: refreshFromDisk,
              emptyMessage: 'No songs in this folder.\nPull down to rescan.',
            ),
      bottomNavigationBar: const MediaControls(),
    );
  }
}
