import 'package:flutter/material.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:free_music_player/components/my_drawer.dart';
import 'package:free_music_player/components/update_banner.dart';
import 'package:free_music_player/constants/app_info.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/pages/playlist_songs_page.dart';
import 'package:free_music_player/pages/settings_page.dart';
import 'package:provider/provider.dart';

/// Folder playlists: one per sub-folder of the music folder.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final playlists = context.select<PlaylistProvider, List<Playlist>>((p) => p.playlists);
    final isSyncing = context.select<PlaylistProvider, bool>((p) => p.isSyncing);
    final hasFolder =
        context.select<PlaylistProvider, bool>((p) => p.musicDirectoryPath.isNotEmpty);
    final provider = context.read<PlaylistProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppInfo.name),
        bottom: isSyncing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      drawer: const MyDrawer(),
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.refreshLibrary,
              child: !hasFolder
                  ? const _EmptyState(
                      message: 'Choose the folder where your music lives.',
                      showSettingsButton: true,
                    )
                  : playlists.isEmpty
                      ? const _EmptyState(
                          message: 'No playlist folders found.\n'
                              'Each folder inside your music folder becomes a playlist.',
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: playlists.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) =>
                              _PlaylistTile(playlist: playlists[index]),
                        ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MediaControls(),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = playlist.songCount ?? 0;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: const Icon(Icons.queue_music),
      ),
      title: Text(playlist.playlistName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(count == 1 ? '1 song' : '$count songs'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlaylistSongsPage(playlist: playlist)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final bool showSettingsButton;
  const _EmptyState({required this.message, this.showSettingsButton = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A scrollable list, so pull-to-refresh works on empty screens too.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.library_music_outlined, size: 64, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
        ),
        if (showSettingsButton) ...[
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Open settings'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
