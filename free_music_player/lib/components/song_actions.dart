import 'package:flutter/material.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:provider/provider.dart';

/// Asks for confirmation, then deletes the song's file from the device.
/// Returns true when it was deleted.
Future<bool> confirmAndDeleteSong(BuildContext context, Song song) async {
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete song'),
      content: Text('Delete "${song.songName}" permanently from this device?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final deleted = await context.read<PlaylistProvider>().deleteSong(song);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(deleted
          ? 'Deleted ${song.songName}'
          : 'Could not delete ${song.songName}. Check the storage permission.'),
    ));
  }
  return deleted;
}
