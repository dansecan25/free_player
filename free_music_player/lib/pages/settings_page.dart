import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/services/theme_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Request storage permission if not granted, then pick folder
  Future<void> requestStoragePermission() async {
    final hasStoragePermission = await Permission.manageExternalStorage.isGranted ||
        await Permission.audio.isGranted;

    if (hasStoragePermission) {
      pickMusicFolder();
      return;
    }

    // Request permissions only if not already granted
    final statuses = await [
      Permission.manageExternalStorage,
      Permission.audio,
    ].request();

    final granted = (statuses[Permission.manageExternalStorage]?.isGranted ?? false) ||
        (statuses[Permission.audio]?.isGranted ?? false);

    if (granted) {
      pickMusicFolder();
    } else {
      // Show a message if permissions are denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission to access storage is denied.')),
      );
    }
  }

  /// Pick a directory and update the PlaylistProvider
  void pickMusicFolder() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      Provider.of<PlaylistProvider>(
        context,
        listen: false,
      ).setMusicDirectory(selectedDirectory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text("Settings")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            children: [
              // Dark Mode Toggle
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(25),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Dark Mode",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Consumer<ThemeService>(
                      builder: (context, themeService, child) {
                        return CupertinoSwitch(
                          value: themeService.isDarkMode,
                          onChanged: (value) => themeService.toggleTheme(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Music Folder Picker
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Music Folder",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Consumer<PlaylistProvider>(
                      builder: (context, playlistProvider, child) {
                        return Text(
                          playlistProvider.musicDirectoryPath.isNotEmpty
                              ? playlistProvider.musicDirectoryPath
                              : "No folder selected",
                          style: const TextStyle(color: Colors.white70),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: requestStoragePermission,
                      child: const Text("Select Folder"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
