import 'package:flutter/material.dart';
import 'package:free_music_player/constants/app_info.dart';
import 'package:free_music_player/pages/all_songs_page.dart';
import 'package:free_music_player/pages/playlists_page.dart';
import 'package:free_music_player/pages/settings_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context); // close the drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: scheme.primaryContainer),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note, size: 48, color: scheme.onPrimaryContainer),
                const SizedBox(height: 8),
                Text(
                  AppInfo.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Folder playlists'),
            onTap: () => Navigator.pop(context), // home is the folder view
          ),
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('My playlists'),
            onTap: () => _go(context, const PlaylistsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.library_music),
            title: const Text('All songs'),
            onTap: () => _go(context, const AllSongsPage()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => _go(context, const SettingsPage()),
          ),
        ],
      ),
    );
  }
}
