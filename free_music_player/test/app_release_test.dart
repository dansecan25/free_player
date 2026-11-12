import 'package:flutter_test/flutter_test.dart';
import 'package:free_music_player/services/app_update_service.dart';

void main() {
  Map<String, dynamic> release({List<Map<String, dynamic>> assets = const []}) => {
        'tag_name': 'v1.2.3',
        'body': 'Notes',
        'assets': assets,
      };

  test('reads the version, APK asset and SHA-256 digest', () {
    final parsed = AppRelease.fromGitHub(release(assets: [
      {'name': 'notes.txt', 'browser_download_url': 'https://example.com/n', 'size': 1},
      {
        'name': 'cumbionsito-player-1.2.3.apk',
        'browser_download_url': 'https://example.com/app.apk',
        'size': 1234,
        'digest': 'sha256:abc123',
      },
    ]))!;

    expect(parsed.version, '1.2.3');
    expect(parsed.apkName, 'cumbionsito-player-1.2.3.apk');
    expect(parsed.apkUrl.toString(), 'https://example.com/app.apk');
    expect(parsed.apkSize, 1234);
    expect(parsed.sha256, 'abc123');
  });

  test('returns null when the release has no APK', () {
    expect(AppRelease.fromGitHub(release()), isNull);
  });

  test('a missing or non-SHA-256 digest is skipped', () {
    final parsed = AppRelease.fromGitHub(release(assets: [
      {
        'name': 'app.APK',
        'browser_download_url': 'https://example.com/app.apk',
        'size': 1,
        'digest': 'md5:zzz',
      },
    ]))!;
    expect(parsed.sha256, isNull);
  });
}
