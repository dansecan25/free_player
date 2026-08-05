import 'dart:convert';
import 'dart:typed_data';

/// Represents a row in the SONGS table.
///
/// - [folderLocations] — every folder path that contains a file for this song
///   (same song can live in multiple scanned folders).
/// - [playlists] — reserved for a future manual-playlist feature; starts null.
/// - [thumbnailData] — raw JPEG/PNG bytes of the embedded album art, or null.
class SongRecord {
  final int? id;
  final String title;
  final String author;
  final String? album;
  final String path; // canonical audio file path (primary key semantically)
  final List<String> folderLocations;
  final List<String>? playlists; // null until the playlist feature is added
  final Uint8List? thumbnailData;

  SongRecord({
    this.id,
    required this.title,
    required this.author,
    this.album,
    required this.path,
    required this.folderLocations,
    this.playlists,
    this.thumbnailData,
  });

  // ── Serialisation helpers ────────────────────────────────────────────────

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'author': author,
      'album': album,
      'path': path,
      'folder_locations': jsonEncode(folderLocations),
      'playlists': playlists != null ? jsonEncode(playlists) : null,
      'thumbnail_data': thumbnailData,
    };
  }

  factory SongRecord.fromMap(Map<String, dynamic> map) {
    return SongRecord(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String,
      album: map['album'] as String?,
      path: map['path'] as String,
      folderLocations: map['folder_locations'] != null
          ? List<String>.from(jsonDecode(map['folder_locations'] as String))
          : [],
      playlists: map['playlists'] != null
          ? List<String>.from(jsonDecode(map['playlists'] as String))
          : null,
      thumbnailData: map['thumbnail_data'] != null
          ? map['thumbnail_data'] as Uint8List
          : null,
    );
  }
}
