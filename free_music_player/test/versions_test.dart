import 'package:flutter_test/flutter_test.dart';
import 'package:free_music_player/utils/versions.dart';

void main() {
  test('compares numerically, not alphabetically', () {
    expect(isNewerVersion('1.0.10', '1.0.9'), isTrue);
    expect(isNewerVersion('1.0.9', '1.0.10'), isFalse);
  });

  test('ignores a leading v and build or pre-release suffixes', () {
    expect(compareVersions('v1.2.0', '1.2.0'), 0);
    expect(compareVersions('1.2.0+7', '1.2.0'), 0);
    expect(compareVersions('1.2.0-beta', '1.2.0'), 0);
  });

  test('treats missing parts as zero', () {
    expect(compareVersions('1.2', '1.2.0'), 0);
    expect(isNewerVersion('1.2.1', '1.2'), isTrue);
  });

  test('the same version is not an update', () {
    expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
  });
}
