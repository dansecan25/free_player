import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:free_music_player/constants/app_info.dart';
import 'package:free_music_player/utils/versions.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UpdateStatus { idle, checking, upToDate, available, downloading, readyToInstall, error }

/// A published GitHub release that has an APK attached.
class AppRelease {
  final String version;
  final String notes;
  final String apkName;
  final Uri apkUrl;
  final int apkSize;
  final String? sha256;

  const AppRelease({
    required this.version,
    required this.notes,
    required this.apkName,
    required this.apkUrl,
    required this.apkSize,
    this.sha256,
  });

  /// Returns null when the release has no APK asset.
  static AppRelease? fromGitHub(Map<String, dynamic> json) {
    final assets = (json['assets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final apk = assets.where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'));
    if (apk.isEmpty) return null;
    final asset = apk.first;
    // GitHub reports release asset digests as "sha256:<hex>".
    final digest = asset['digest'] as String?;
    return AppRelease(
      version: (json['tag_name'] as String).replaceFirst(RegExp(r'^[vV]'), ''),
      notes: json['body'] as String? ?? '',
      apkName: asset['name'] as String,
      apkUrl: Uri.parse(asset['browser_download_url'] as String),
      apkSize: asset['size'] as int? ?? 0,
      sha256: digest != null && digest.startsWith('sha256:') ? digest.substring(7) : null,
    );
  }
}

/// Checks GitHub Releases for a newer APK, downloads it and opens the installer.
/// Only Android release builds update themselves.
class AppUpdateService extends ChangeNotifier {
  static const String _lastCheckKey = 'update_last_check_ms';
  static const String _autoCheckKey = 'update_auto_check';
  static const MethodChannel _channel = MethodChannel(AppInfo.updaterChannel);

  final SharedPreferences _prefs;

  UpdateStatus _status = UpdateStatus.idle;
  String? _installedVersion;
  AppRelease? _release;
  double _progress = 0;
  String? _error;
  bool _dismissed = false;
  File? _downloadedApk;

  AppUpdateService(this._prefs);

  static bool get isSupported => !kIsWeb && Platform.isAndroid && kReleaseMode;

  UpdateStatus get status => _status;
  String? get installedVersion => _installedVersion;
  AppRelease? get release => _release;
  double get progress => _progress;
  String? get error => _error;
  bool get autoCheck => _prefs.getBool(_autoCheckKey) ?? true;

  /// Whether to show the update banner.
  bool get shouldNotify =>
      !_dismissed &&
      (_status == UpdateStatus.available ||
          _status == UpdateStatus.downloading ||
          _status == UpdateStatus.readyToInstall ||
          (_status == UpdateStatus.error && _release != null));

  void _set(UpdateStatus status, {String? error}) {
    _status = status;
    _error = error;
    notifyListeners();
  }

  Future<void> setAutoCheck(bool enabled) async {
    await _prefs.setBool(_autoCheckKey, enabled);
    notifyListeners();
  }

  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }

  Future<String?> loadInstalledVersion() async {
    if (_installedVersion != null || !isSupported) return _installedVersion;
    final info = await _channel.invokeMapMethod<String, dynamic>('getAppVersion');
    _installedVersion = info?['versionName'] as String?;
    notifyListeners();
    return _installedVersion;
  }

  /// Checks for a newer release. Automatic checks ([manual] false) respect the
  /// setting and the check interval, and stay quiet when offline.
  Future<void> checkForUpdates({bool manual = false}) async {
    if (!isSupported) return;
    if (_status == UpdateStatus.checking || _status == UpdateStatus.downloading) return;
    if (!manual) {
      final lastCheck = _prefs.getInt(_lastCheckKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastCheck;
      if (!autoCheck || elapsed < AppInfo.updateCheckInterval.inMilliseconds) return;
    }

    _set(UpdateStatus.checking);
    try {
      final installed = await loadInstalledVersion();
      final release = await _fetchLatestRelease();
      await _prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
      if (release != null && installed != null && isNewerVersion(release.version, installed)) {
        _release = release;
        _dismissed = false;
        _set(UpdateStatus.available);
      } else {
        _set(manual ? UpdateStatus.upToDate : UpdateStatus.idle);
      }
    } catch (error) {
      debugPrint('Update check failed: $error');
      _set(manual ? UpdateStatus.error : UpdateStatus.idle, error: _describe(error));
    }
  }

  Future<AppRelease?> _fetchLatestRelease() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(AppInfo.latestReleaseUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == HttpStatus.notFound) return null;
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('GitHub answered with status ${response.statusCode}');
      }
      return AppRelease.fromGitHub(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  /// Downloads the APK and checks it against the size and digest GitHub reports.
  Future<void> download() async {
    final release = _release;
    if (release == null || _status == UpdateStatus.downloading) return;
    _progress = 0;
    _set(UpdateStatus.downloading);

    final client = HttpClient();
    try {
      final folder = Directory(p.join(
          (await getApplicationCacheDirectory()).path, AppInfo.updateCacheDir));
      if (await folder.exists()) await folder.delete(recursive: true);
      await folder.create(recursive: true);
      final file = File(p.join(folder.path, p.basename(release.apkName)));

      final response = await (await client.getUrl(release.apkUrl)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Download failed with status ${response.statusCode}');
      }
      final total = response.contentLength > 0 ? response.contentLength : release.apkSize;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            _progress = received / total;
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }

      if (release.apkSize > 0 && await file.length() != release.apkSize) {
        throw const FileSystemException('The download is incomplete. Please try again.');
      }
      if (release.sha256 != null) {
        final hash = await _channel.invokeMethod<String>('sha256', {'path': file.path});
        if (hash?.toLowerCase() != release.sha256!.toLowerCase()) {
          await file.delete();
          throw const FileSystemException(
              'The download does not match the published release. Please try again.');
        }
      }
      _downloadedApk = file;
      _set(UpdateStatus.readyToInstall);
    } catch (error) {
      debugPrint('Update download failed: $error');
      _set(UpdateStatus.error, error: _describe(error));
    } finally {
      client.close();
    }
  }

  /// Whether Android lets this app open the package installer.
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstallPackages') ?? false;

  Future<void> openInstallPermissionSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');

  /// Opens Android's installer for the downloaded APK.
  Future<void> install() async {
    final file = _downloadedApk;
    if (file == null) return;
    try {
      await _channel.invokeMethod<void>('installApk', {'path': file.path});
    } catch (error) {
      _set(UpdateStatus.error, error: _describe(error));
    }
  }

  String _describe(Object error) {
    if (error is SocketException) return 'No internet connection.';
    if (error is FileSystemException) return error.message;
    if (error is HttpException) return error.message;
    if (error is PlatformException) return error.message ?? error.code;
    return error.toString();
  }
}
