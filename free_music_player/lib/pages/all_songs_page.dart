import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:free_music_player/components/add_to_playlist_dialog.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/models/song_record.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:provider/provider.dart';

/// Flat list of every song indexed in the SONGS table.
class AllSongsPage extends StatefulWidget {
  const AllSongsPage({super.key});

  @override
  State<AllSongsPage> createState() => _AllSongsPageState();
}

class _AllSongsPageState extends State<AllSongsPage> {
  List<Song> _allSongs = [];
  List<Song> _filtered = [];
  bool _loading = true;
  String _query = '';
  bool _isReversed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = Provider.of<PlaylistProvider>(context, listen: false).dbService;
    final records = await db.getAllSongs();
    final songs = records.map(_recordToSong).toList();
    if (mounted) {
      setState(() {
        _allSongs = songs;
        _filtered = songs;
        _loading = false;
      });
    }
  }

  Song _recordToSong(SongRecord r) => Song(
        songName: r.title,
        artistName: r.author,
        albumArtImagePathBytes: r.thumbnailData,
        audioPath: File(r.path),
      );

  void _filter(String q) {
    setState(() {
      _query = q;
      _filtered = _allSongs
          .where((s) => s.songName.toLowerCase().contains(q.toLowerCase()) ||
              s.artistName.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  void _play(Song song) {
    final provider = Provider.of<PlaylistProvider>(context, listen: false);
    provider.playFromList(_filtered, song);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SongPage(songObject: song)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Songs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: _filter,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_vert, size: 28),
                  tooltip: 'Reverse order',
                  onPressed: () {
                    setState(() {
                      _isReversed = !_isReversed;
                      _filtered = _filtered.reversed.toList();
                      _allSongs = _allSongs.reversed.toList();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(
                  child: Text(
                    _query.isEmpty ? 'No songs in library' : 'No results',
                    style: const TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) {
                    final song = _filtered[i];
                    return _SongTile(song: song, onTap: () => _play(song));
                  },
                ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final provider = Provider.of<PlaylistProvider>(context, listen: false);
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: ValueListenableBuilder<Uint8List?>(
            valueListenable: song.albumArtNotifier,
            builder: (_, bytes, __) {
              if (bytes == null) return const Icon(Icons.music_note, size: 70);
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
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.artistName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'add_to_playlist') {
                await showAddToPlaylistDialog(context, song);
              } else if (value == 'delete') {
                await provider.deleteSong(context, song, 0);
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
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Color.fromARGB(255, 255, 105, 94)),
                    SizedBox(width: 8),
                    Text('Delete'),
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
  }
}
