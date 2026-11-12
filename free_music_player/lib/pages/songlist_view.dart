import 'package:flutter/material.dart';
import 'package:free_music_player/components/add_to_playlist_dialog.dart';
import 'package:free_music_player/components/artwork_thumbnail.dart';
import 'package:free_music_player/components/song_actions.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/utils/song_sorting.dart';
import 'package:provider/provider.dart';

/// Searchable song list sorted by name, shared by every song screen.
///
/// Tapping a song calls [onSongTap] with the full list in the order shown
/// (ignoring the search), which becomes the playback queue.
class SongListView extends StatefulWidget {
  final List<Song> songs;
  final void Function(Song song, List<Song> queue) onSongTap;
  final Future<void> Function() onRefresh;

  /// Shown in the song menu when set, for user playlists.
  final Future<void> Function(Song song)? onRemoveFromPlaylist;
  final String emptyMessage;

  const SongListView({
    super.key,
    required this.songs,
    required this.onSongTap,
    required this.onRefresh,
    this.onRemoveFromPlaylist,
    this.emptyMessage = 'No songs here yet.',
  });

  @override
  State<SongListView> createState() => _SongListViewState();
}

class _SongListViewState extends State<SongListView> {
  String _query = '';
  bool _reversed = false;
  late List<Song> _sorted;
  late List<Song> _visible;

  @override
  void initState() {
    super.initState();
    _reversed = context.read<PlaylistProvider>().stateService?.getSortReversed() ?? false;
    _apply();
  }

  @override
  void didUpdateWidget(SongListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.songs, widget.songs)) _apply();
  }

  void _apply() {
    _sorted = sortSongsByName(widget.songs, reversed: _reversed);
    _visible = filterSongs(_sorted, _query);
  }

  void _toggleOrder() {
    setState(() {
      _reversed = !_reversed;
      _apply();
    });
    context.read<PlaylistProvider>().stateService?.saveSortReversed(_reversed);
  }

  Future<void> _onMenu(String action, Song song) async {
    switch (action) {
      case 'add':
        await showAddToPlaylistDialog(context, song);
      case 'remove':
        await widget.onRemoveFromPlaylist?.call(song);
      case 'delete':
        await confirmAndDeleteSong(context, song);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search songs or artists',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {
                    _query = value;
                    _apply();
                  }),
                ),
              ),
              IconButton(
                icon: Icon(_reversed ? Icons.south : Icons.north),
                tooltip: _reversed ? 'Sorted Z–A. Sort A–Z' : 'Sorted A–Z. Sort Z–A',
                onPressed: _toggleOrder,
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: _visible.isEmpty
                ? ListView(
                    // Scrollable so pull-to-refresh also works when empty.
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(48),
                        child: Text(
                          _query.isEmpty ? widget.emptyMessage : 'No results',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _visible.length,
                    itemBuilder: (context, index) {
                      final song = _visible[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.only(left: 16, right: 4),
                        leading: ArtworkThumbnail(song: song),
                        title: Text(song.songName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(song.artistName,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => widget.onSongTap(song, _sorted),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Song options',
                          onSelected: (action) => _onMenu(action, song),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'add',
                              child: ListTile(
                                leading: Icon(Icons.playlist_add),
                                title: Text('Add to playlist'),
                              ),
                            ),
                            if (widget.onRemoveFromPlaylist != null)
                              const PopupMenuItem(
                                value: 'remove',
                                child: ListTile(
                                  leading: Icon(Icons.playlist_remove),
                                  title: Text('Remove from playlist'),
                                ),
                              ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline, color: scheme.error),
                                title: const Text('Delete from device'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
