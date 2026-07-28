import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:free_music_player/pages/songlist_view.dart';

/// Shows the songs inside a single playlist. This is its own page/route
/// (instead of being swapped in-place inside HomePage) so that:
///  - navigating here/back is a normal push/pop instead of a state flag
///  - artwork loading only needs to repaint this page, not the whole app
class PlaylistSongsPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistSongsPage({super.key, required this.playlist});

  @override
  State<PlaylistSongsPage> createState() => _PlaylistSongsPageState();
}

class _PlaylistSongsPageState extends State<PlaylistSongsPage> {
  List<Song> songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final playlistProvider =
        Provider.of<PlaylistProvider>(context, listen: false);

    // Already loaded from a previous visit (e.g. navigated back and forth)
    // -- reuse it instead of rescanning the directory and redecoding every
    // song's artwork again.
    final cached = widget.playlist.playlistSongs;
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        songs = cached;
        _loading = false;
      });
      return;
    }

    final loadedSongs = await playlistProvider.setSongsForPlaylist(
      widget.playlist.directoryPath,
      // No-op: each Song's own albumArtNotifier (see song.dart) handles
      // repainting its own thumbnail as artwork arrives. We deliberately
      // don't setState here -- rebuilding the whole page/list on every
      // batch is what made scrolling feel laggy while art was loading.
      onArtworkBatchLoaded: (_) {},
    );

    widget.playlist.setSongs(loadedSongs);

    if (mounted) {
      setState(() {
        songs = loadedSongs;
        _loading = false;
      });
    }
  }

  void _goToSong(Song songObject, int songIndex) {
    final playlistProvider =
        Provider.of<PlaylistProvider>(context, listen: false);
    playlistProvider.playFromList(songs, songObject);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SongPage(songObject: songObject)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(widget.playlist.playlistName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : songs.isEmpty
              ? const Center(child: Text("No songs in this playlist"))
              : SongListView(songs: songs, onSongTap: _goToSong),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(0.0),
        child: MediaControls(),
      ),
    );
  }
}
