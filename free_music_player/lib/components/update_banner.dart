import 'package:flutter/material.dart';
import 'package:free_music_player/services/app_update_service.dart';
import 'package:provider/provider.dart';

/// Opens the installer for a downloaded update. Android first needs the user to
/// allow installs from this app; if that's off, explain and open the setting.
Future<void> installUpdateWithPrompts(BuildContext context) async {
  final updates = context.read<AppUpdateService>();
  if (await updates.canInstall()) {
    await updates.install();
    return;
  }
  if (!context.mounted) return;
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Allow updates'),
      content: const Text(
          'Allow Cumbionsito Player to install updates, then come back and tap Install.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Open settings'),
        ),
      ],
    ),
  );
  if (openSettings == true) await updates.openInstallPermissionSettings();
}

/// Card at the top of the home screen while an update is available,
/// downloading or ready to install.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<AppUpdateService>();
    if (!updates.shouldNotify) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final version = updates.release?.version ?? '';
    final downloading = updates.status == UpdateStatus.downloading;
    final ready = updates.status == UpdateStatus.readyToInstall;
    final failed = updates.status == UpdateStatus.error;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update, color: scheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    downloading
                        ? 'Downloading version $version… ${(updates.progress * 100).round()}%'
                        : failed
                            ? 'Update failed: ${updates.error}'
                            : ready
                            ? 'Version $version is ready to install.'
                            : 'Version $version is available.',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: updates.progress),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  if (!downloading)
                    TextButton(onPressed: updates.dismiss, child: const Text('Later')),
                  if (!downloading)
                    FilledButton(
                      onPressed: ready
                          ? () => installUpdateWithPrompts(context)
                          : updates.download,
                      child: Text(ready ? 'Install' : failed ? 'Retry' : 'Update'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
