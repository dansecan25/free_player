/// Tuning values for scanning and displaying the music library.
class LibraryLimits {
  LibraryLimits._();

  static const Set<String> musicExtensions = {'.mp3', '.flac'};

  /// Files whose metadata is read per background isolate call, which bounds
  /// how much album art is held in memory at once.
  static const int metadataBatchSize = 25;

  /// Edge of the square JPEG thumbnail stored for list tiles. The full
  /// artwork is only loaded on the song page.
  static const int thumbnailSize = 160;
  static const int thumbnailQuality = 80;

  static const String unknownArtist = 'Unknown artist';
}
