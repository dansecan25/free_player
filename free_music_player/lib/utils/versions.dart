/// Compares dotted version strings such as "1.0.10" and "v1.2". Missing parts
/// count as zero and anything after "+" or "-" is ignored. Returns a negative
/// number, zero or a positive number like [Comparable.compareTo].
int compareVersions(String a, String b) {
  List<int> parts(String version) => version
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[+-]'))
      .first
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();

  final left = parts(a);
  final right = parts(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final difference =
        (i < left.length ? left[i] : 0) - (i < right.length ? right[i] : 0);
    if (difference != 0) return difference;
  }
  return 0;
}

bool isNewerVersion(String candidate, String installed) =>
    compareVersions(candidate, installed) > 0;
