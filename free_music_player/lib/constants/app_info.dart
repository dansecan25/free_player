/// Fixed app-wide values: name, release source and update timing.
class AppInfo {
  AppInfo._();

  static const String name = 'Cumbionsito Player';

  // In-app updates come from this repository's GitHub Releases. Drafts and
  // pre-releases are ignored, so a release only reaches phones once published.
  static const String releasesRepository = 'dansecan25/free_player';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$releasesRepository/releases/latest';
  static const String releasesPageUrl =
      'https://github.com/$releasesRepository/releases';

  /// Automatic checks run at most this often (at startup and on resume).
  static const Duration updateCheckInterval = Duration(hours: 12);

  /// Must match the `cache-path` in android/app/src/main/res/xml/update_file_paths.xml.
  static const String updateCacheDir = 'updates';

  static const String audioNotificationChannelId =
      'com.dansecan25.cumbionsito.channel.audio';
  static const String audioNotificationChannelName = 'Music playback';

  /// MethodChannel implemented in android/.../MainActivity.kt.
  static const String updaterChannel = 'cumbionsito/updater';
}
