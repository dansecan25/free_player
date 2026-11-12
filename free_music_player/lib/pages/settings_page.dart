import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/components/update_banner.dart';
import 'package:free_music_player/constants/app_info.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/services/app_update_service.dart';
import 'package:free_music_player/services/theme_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _AppearanceSection(),
          const _MusicFolderSection(),
          if (AppUpdateService.isSupported) const _UpdatesSection(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return _Section(
      title: 'Appearance',
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('Device'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('Dark'),
              ),
            ],
            selected: {themeService.mode},
            onSelectionChanged: (selection) => themeService.setMode(selection.first),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Device follows your phone\'s light or dark setting.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MusicFolderSection extends StatelessWidget {
  const _MusicFolderSection();

  Future<bool> _hasStoragePermission() async {
    if (await Permission.manageExternalStorage.isGranted ||
        await Permission.audio.isGranted) {
      return true;
    }
    final statuses = await [Permission.manageExternalStorage, Permission.audio].request();
    return statuses.values.any((status) => status.isGranted);
  }

  Future<void> _pickFolder(BuildContext context) async {
    final library = context.read<PlaylistProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await _hasStoragePermission()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Permission to access storage was denied.')),
      );
      return;
    }
    final folder = await FilePicker.getDirectoryPath();
    if (folder != null) await library.setMusicDirectory(folder);
  }

  @override
  Widget build(BuildContext context) {
    final path = context.select<PlaylistProvider, String>((p) => p.musicDirectoryPath);
    final isSyncing = context.select<PlaylistProvider, bool>((p) => p.isSyncing);
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      title: 'Music folder',
      children: [
        Text(
          path.isNotEmpty ? path : 'No folder selected',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          'Each folder inside it becomes a playlist. New and deleted songs are '
          'picked up when you return to the app, or when you pull down on a list.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Select folder'),
              onPressed: () => _pickFolder(context),
            ),
            if (path.isNotEmpty)
              OutlinedButton.icon(
                icon: isSyncing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: const Text('Rescan now'),
                onPressed: isSyncing
                    ? null
                    : () => context.read<PlaylistProvider>().refreshLibrary(),
              ),
          ],
        ),
      ],
    );
  }
}

class _UpdatesSection extends StatefulWidget {
  const _UpdatesSection();

  @override
  State<_UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends State<_UpdatesSection> {
  @override
  void initState() {
    super.initState();
    context.read<AppUpdateService>().loadInstalledVersion();
  }

  String? _statusText(AppUpdateService updates) {
    final version = updates.release?.version;
    return switch (updates.status) {
      UpdateStatus.checking => 'Checking for updates…',
      UpdateStatus.upToDate => 'You have the latest version.',
      UpdateStatus.available => 'Version $version is available.',
      UpdateStatus.downloading =>
        'Downloading version $version… ${(updates.progress * 100).round()}%',
      UpdateStatus.readyToInstall => 'Version $version is ready to install.',
      UpdateStatus.error => 'Update failed: ${updates.error}',
      UpdateStatus.idle => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<AppUpdateService>();
    final busy = updates.status == UpdateStatus.checking ||
        updates.status == UpdateStatus.downloading;
    final status = _statusText(updates);
    final canDownload = updates.release != null &&
        (updates.status == UpdateStatus.available || updates.status == UpdateStatus.error);

    return _Section(
      title: 'App updates',
      children: [
        Text('Installed version: ${updates.installedVersion ?? '-'}'),
        if (status != null) ...[
          const SizedBox(height: 4),
          Text(status, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Check automatically'),
          subtitle: const Text('At startup and when you come back to the app'),
          value: updates.autoCheck,
          onChanged: updates.setAutoCheck,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: busy ? null : () => updates.checkForUpdates(manual: true),
              child: const Text('Check now'),
            ),
            if (updates.status == UpdateStatus.readyToInstall)
              FilledButton(
                onPressed: () => installUpdateWithPrompts(context),
                child: const Text('Install update'),
              )
            else if (canDownload)
              FilledButton(
                onPressed: updates.download,
                child: const Text('Download and install'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          'Releases: ${AppInfo.releasesPageUrl}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
