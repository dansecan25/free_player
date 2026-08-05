import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:free_music_player/pages/songlist_view.dart';

class PlaylistSongsPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistSongsPage({super.key, required this.playlist});

  @override
  State<PlaylistSongsPage> createState() => _PlaylistSongsPageState();
}

class _PlaylistSongsPageState extends State<PlaylistSongsPage> {
  List<Song> songs = [];
  // Start as "loading" only when we have no cached songs at all.
  // The list is shown immediately once we have any data.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final playlistProvider =
        Provider.of<PlaylistProvider>(context, listen: false);

    // Re-use cached songs — no flicker on back-navigation.
    final cached = widget.playlist.playlistSongs;
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        songs = cached;
        _loading = false;
      });
      return;
    }

    // Show the skeleton immediately so the page never looks frozen.
    // The actual load is fast (single DB query), but even a ~50ms wait
    // feels instant when the skeleton is already animating.
    setState(() => _loading = true);

    final loadedSongs = await playlistProvider.setSongsForPlaylist(
      widget.playlist.directoryPath,
      // Album art is already embedded in each Song via thumbnailSmall from the
      // DB, so we don't need to trigger extra repaints here.
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
          ? const _SongListSkeleton()
          : songs.isEmpty
              ? const Center(child: Text("No songs in this playlist"))
              : SongListView(songs: songs, onSongTap: _goToSong),
      bottomNavigationBar: const MediaControls(),
    );
  }
}

// ── Skeleton loading list ─────────────────────────────────────────────────────

/// Animated placeholder rows shown while songs are loading.
/// Mimics the real tile layout so there is no layout jump on content arrival.
class _SongListSkeleton extends StatefulWidget {
  const _SongListSkeleton();

  @override
  State<_SongListSkeleton> createState() => _SongListSkeletonState();
}

class _SongListSkeletonState extends State<_SongListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer = base.withAlpha(
            (20 + (_anim.value * 30)).round()); // 20–50 alpha
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          itemBuilder: (_, __) => _SkeletonTile(color: shimmer),
        );
      },
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  final Color color;
  const _SkeletonTile({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Thumbnail placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              // Text placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 11,
                      width: 120,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, indent: 16, endIndent: 16, color: color),
      ],
    );
  }
}
