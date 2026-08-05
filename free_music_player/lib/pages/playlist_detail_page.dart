import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:free_music_player/components/add_to_playlist_dialog.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:free_music_player/models/db_playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/models/song_record.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:provider/provider.dart';

/// Shows all songs in a DB playlist. The AppBar "+" opens the full song
/// library with checkboxes so the user can add / remove songs.
class PlaylistDetailPage extends StatefulWidget {
  final DbPlaylist playlist;

  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  List<Song> _songs = [];
  List<Song> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = Provider.of<PlaylistProvider>(context, listen: false).dbService;
    final records = await db.getSongsForPlaylist(widget.playlist.id);
    if (mounted) {
      setState(() {
        _songs = records.map(_toSong).toList();
        _filtered = _songs;
        _searchQuery = '';
        _loading = false;
      });
    }
  }

  void _filterSongs(String query) {
    setState(() {
      _searchQuery = query;
      _filtered = _songs
          .where((s) =>
              s.songName.toLowerCase().contains(query.toLowerCase()) ||
              s.artistName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Song _toSong(SongRecord r) => Song(
        songName: r.title,
        artistName: r.author,
        albumArtImagePathBytes: r.thumbnailData,
        audioPath: File(r.path),
      );

  void _play(Song song) {
    final provider = Provider.of<PlaylistProvider>(context, listen: false);
    provider.playFromList(_filtered, song);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SongPage(songObject: song)),
    );
  }

  Future<void> _openSongPicker() async {
    final db = Provider.of<PlaylistProvider>(context, listen: false).dbService;
    final allRecords = await db.getAllSongs();
    final alreadyIn = await db.getPathsInPlaylist(widget.playlist.id);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SongPickerSheet(
        playlistId: widget.playlist.id,
        allRecords: allRecords,
        initiallySelected: alreadyIn,
        dbService: db,
      ),
    );

    // Reload after picker closes
    await _load();
  }

  Future<void> _removeSong(Song song) async {
    final db = Provider.of<PlaylistProvider>(context, listen: false).dbService;
    await db.removeSongFromPlaylist(widget.playlist.id, song.audioPath.path);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _songs.isEmpty
              ? const Center(
                  child: Text(
                    'No songs yet.\nTap + to add some.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    // ── Search + Shuffle bar ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 4, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search songs…',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                isDense: true,
                              ),
                              onChanged: _filterSongs,
                            ),
                          ),
                          Builder(
                            builder: (ctx) {
                              final provider = Provider.of<PlaylistProvider>(
                                  ctx, listen: false);
                              return IconButton(
                                icon: Icon(
                                  Icons.shuffle,
                                  color: provider.isShuffling
                                      ? Theme.of(ctx).colorScheme.primary
                                      : null,
                                ),
                                tooltip: 'Shuffle',
                                onPressed: () {
                                  provider.shuffle();
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // ── Song list ────────────────────────────────────────
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'No songs yet.\nTap + to add some.'
                                    : 'No results',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filtered.length,
                              itemBuilder: (ctx, i) {
                                final song = _filtered[i];
                                final dpr = MediaQuery.of(context).devicePixelRatio;
                                final provider = Provider.of<PlaylistProvider>(
                                    ctx, listen: false);
                                return Column(
                                  children: [
                                    ListTile(
                                      onTap: () => _play(song),
                                      leading: ValueListenableBuilder<Uint8List?>(
                                        valueListenable: song.albumArtNotifier,
                                        builder: (_, bytes, __) {
                                          if (bytes == null) {
                                            return const Icon(
                                                Icons.music_note, size: 70);
                                          }
                                          return RepaintBoundary(
                                            child: Image.memory(
                                              bytes,
                                              width: 75,
                                              height: 90,
                                              fit: BoxFit.cover,
                                              cacheWidth: (75 * dpr).round(),
                                              cacheHeight: (90 * dpr).round(),
                                              gaplessPlayback: true,
                                            ),
                                          );
                                        },
                                      ),
                                      title: Text(song.songName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      subtitle: Text(song.artistName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      trailing: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (value) async {
                                          if (value == 'add_to_playlist') {
                                            await showAddToPlaylistDialog(
                                                ctx, song);
                                          } else if (value == 'remove') {
                                            await _removeSong(song);
                                          } else if (value == 'delete') {
                                            await provider.deleteSong(
                                                ctx, song, i);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'add_to_playlist',
                                            child: Row(
                                              children: [
                                                Icon(Icons.playlist_add),
                                                SizedBox(width: 8),
                                                Text('Add to playlist'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'remove',
                                            child: Row(
                                              children: [
                                                Icon(Icons.playlist_remove),
                                                SizedBox(width: 8),
                                                Text('Remove from playlist'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete,
                                                    color: Color.fromARGB(
                                                        255, 255, 105, 94)),
                                                SizedBox(width: 8),
                                                Text('Delete from device'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                      color: Color(0x26000000),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
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
  final dynamic dbService; // DatabaseService — avoid circular import

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
  late Set<String> _selected;
  List<SongRecord> _filtered = [];

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initiallySelected);
    _filtered = widget.allRecords;
  }

  void _filter(String q) {
    setState(() {
      _filtered = widget.allRecords
          .where((r) =>
              r.title.toLowerCase().contains(q.toLowerCase()) ||
              r.author.toLowerCase().contains(q.toLowerCase()))
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
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final mq = MediaQuery.of(context);

    return SizedBox(
      height: mq.size.height * 0.85,
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Add songs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
              decoration: InputDecoration(
                hintText: 'Search songs…',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final record = _filtered[i];
                final checked = _selected.contains(record.path);
                return CheckboxListTile(
                  value: checked,
                  onChanged: (_) => _toggle(record),
                  secondary: record.thumbnailData != null
                      ? RepaintBoundary(
                          child: Image.memory(
                            record.thumbnailData!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            cacheWidth: (48 * dpr).round(),
                            cacheHeight: (48 * dpr).round(),
                            gaplessPlayback: true,
                          ),
                        )
                      : const Icon(Icons.music_note, size: 48),
                  title: Text(record.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(record.author,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
