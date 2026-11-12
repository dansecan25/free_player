import 'package:flutter/material.dart';
import 'package:free_music_player/components/artwork_thumbnail.dart';
import 'package:free_music_player/components/library_reload_mixin.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:free_music_player/components/song_list_skeleton.dart';
import 'package:free_music_player/models/db_playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/models/song_record.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:free_music_player/pages/songlist_view.dart';
import 'package:free_music_player/services/database_service.dart';
import 'package:provider/provider.dart';

/// Songs in a user playlist. "+" opens the library to add or remove songs.
class PlaylistDetailPage extends StatefulWidget {
  final DbPlaylist playlist;

  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> with LibraryReloadMixin {
  List<Song>? _songs;

  DatabaseService get _db => context.read<PlaylistProvider>().dbService;

  @override
  void initState() {
    super.initState();
    reloadSongs();
  }

  @override
  Future<void> reloadSongs() async {
    final records = await _db.getSongsForPlaylist(widget.playlist.id);
    if (mounted) setState(() => _songs = records.map(songFromRecord).toList());
  }

  void _play(Song song, List<Song> queue) {
    context.read<PlaylistProvider>().playFromList(queue, song);
    Navigator.push(context, MaterialPageRoute(builder: (_) => SongPage(songObject: song)));
  }

  Future<void> _removeSong(Song song) async {
    await _db.removeSongFromPlaylist(widget.playlist.id, song.path);
    await reloadSongs();
  }

  Future<void> _openSongPicker() async {
    final db = _db;
    final allRecords = await db.getAllSongs();
    final alreadyIn = await db.getPathsInPlaylist(widget.playlist.id);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SongPickerSheet(
        playlistId: widget.playlist.id,
        allRecords: allRecords,
        initiallySelected: alreadyIn,
        dbService: db,
      ),
    );
    await reloadSongs();
  }

  @override
  Widget build(BuildContext context) {
    final songs = _songs;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add songs',
            onPressed: _openSongPicker,
          ),
        ],
      ),
      body: songs == null
          ? const SongListSkeleton()
          : SongListView(
              songs: songs,
              onSongTap: _play,
              onRefresh: refreshFromDisk,
              onRemoveFromPlaylist: _removeSong,
              emptyMessage: 'No songs yet.\nTap + to add some.',
            ),
      bottomNavigationBar: const MediaControls(),
    );
  }
}

// ── Song picker bottom sheet ──────────────────────────────────────────────────

class _SongPickerSheet extends StatefulWidget {
  final int playlistId;
  final List<SongRecord> allRecords;
  final Set<String> initiallySelected;
  final DatabaseService dbService;

  const _SongPickerSheet({
    required this.playlistId,
    required this.allRecords,
    required this.initiallySelected,
    required this.dbService,
  });

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  late final Set<String> _selected = Set.of(widget.initiallySelected);
  late final List<SongRecord> _sorted = List.of(widget.allRecords)
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  late List<SongRecord> _filtered = _sorted;

  void _filter(String query) {
    final needle = query.trim().toLowerCase();
    setState(() {
      _filtered = _sorted
          .where((r) =>
              r.title.toLowerCase().contains(needle) ||
              r.author.toLowerCase().contains(needle))
          .toList();
    });
  }

  Future<void> _toggle(SongRecord record) async {
    final path = record.path;
    if (_selected.contains(path)) {
      await widget.dbService.removeSongFromPlaylist(widget.playlistId, path);
      setState(() => _selected.remove(path));
    } else {
      await widget.dbService.addSongToPlaylist(widget.playlistId, path);
      setState(() => _selected.add(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Add songs', style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search songs or artists',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final record = _filtered[index];
                return CheckboxListTile(
                  value: _selected.contains(record.path),
                  onChanged: (_) => _toggle(record),
                  secondary: ArtworkImage(bytes: record.thumbnailSmall, size: 44),
                  title: Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(record.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
