import 'package:flutter/material.dart';
import 'package:free_music_player/models/db_playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:provider/provider.dart';

/// Shows a dialog listing all DB playlists and adds [song] to the one the
/// user taps. Call from any page that has a BuildContext.
Future<void> showAddToPlaylistDialog(BuildContext context, Song song) async {
  final db = Provider.of<PlaylistProvider>(context, listen: false).dbService;
  final rows = await db.getAllPlaylists();

  if (!context.mounted) return;

  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No playlists yet. Create one first.'),
      ),
    );
    return;
  }

  final playlists = rows.map(DbPlaylist.fromMap).toList();

  await showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Add to playlist'),
      children: playlists.map((pl) {
        return SimpleDialogOption(
          onPressed: () async {
            await db.addSongToPlaylist(pl.id, song.audioPath.path);
            Navigator.pop(ctx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added to "${pl.name}"')),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.queue_music),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(pl.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );
}
