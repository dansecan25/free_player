import 'package:flutter/material.dart';
import 'package:free_music_player/models/db_playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/pages/playlist_detail_page.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:provider/provider.dart';

/// Home for DB-backed playlists (not folder-based).
/// The AppBar "+" creates a new playlist via a dialog.
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  List<DbPlaylist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = Provider.of<PlaylistProvider>(context, listen: false).dbService;
    final rows = await db.getAllPlaylists();
    if (mounted) {
      setState(() {
        _playlists = rows.map(DbPlaylist.fromMap).toList();
        _loading = false;
      });
    }
  }

  Future<void> _createPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    if (!mounted) return;

    final db = Provider.of<PlaylistProvider>(context, listen: false).dbService;
    final id = await db.createPlaylist(name);
    if (id == 0) {
      // ConflictAlgorithm.ignore returns 0 when name already exists
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A playlist with that name already exists')),
        );
      }
      return;
    }
    await _load();
  }

  Future<void> _deletePlaylist(DbPlaylist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Playlist'),
        content: Text('Delete "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final db = Provider.of<PlaylistProvider>(context, listen: false).dbService;
    await db.deletePlaylist(playlist.id);
    await _load();
  }

  void _openPlaylist(DbPlaylist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistDetailPage(playlist: playlist),
      ),
    ).then((_) => _load()); // refresh count after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New playlist',
            onPressed: _createPlaylist,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _playlists.isEmpty
              ? const Center(
                  child: Text(
                    'No playlists yet.\nTap + to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _playlists.length,
                  itemBuilder: (ctx, i) {
                    final pl = _playlists[i];
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.queue_music),
                          title: Text(pl.name),
                          onTap: () => _openPlaylist(pl),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete playlist',
                            onPressed: () => _deletePlaylist(pl),
                          ),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  },
                ),
      bottomNavigationBar: const MediaControls(),
    );
  }
}
