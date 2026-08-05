import 'package:flutter/material.dart';
import 'package:free_music_player/pages/all_songs_page.dart';
import 'package:free_music_player/pages/playlists_page.dart';
import 'package:free_music_player/pages/settings_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context); // close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.inversePrimary;

    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: Center(
              child: Icon(Icons.music_note, size: 40, color: color),
            ),
          ),

          // ── Playlists (DB-backed) ──────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.queue_music),
            title: const Text('Playlists'),
            onTap: () => _go(context, const PlaylistsPage()),
          ),

          // ── Songs ──────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.library_music),
            title: const Text('All Songs'),
            onTap: () => _go(context, const AllSongsPage()),
          ),

          // ── Playlists Legacy (folder = playlist) ───────────────────────
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Playlists Legacy'),
            onTap: () {
              Navigator.pop(context); // just go home (home IS the legacy view)
            },
          ),

          // ── Settings ───────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => _go(context, SettingsPage()),
          ),
        ],
      ),
    );
  }
}

