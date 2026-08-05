import 'dart:convert';
import 'dart:typed_data';

/// Represents a row in the SONGS table.
///
/// - [folderLocations] — every folder path that contains a file for this song.
/// - [playlists] — reserved for future manual-playlist feature; starts null.
/// - [thumbnailData] — full-res JPEG/PNG bytes of embedded album art, or null.
/// - [thumbnailSmall] — ~96×96 compressed JPEG, used for fast list display.
class SongRecord {
  final int? id;
  final String title;
  final String author;
  final String? album;
  final String path;
  final List<String> folderLocations;
  final List<String>? playlists;
  final Uint8List? thumbnailData;
  final Uint8List? thumbnailSmall;

  SongRecord({
    this.id,
    required this.title,
    required this.author,
    this.album,
    required this.path,
    required this.folderLocations,
    this.playlists,
    this.thumbnailData,
    this.thumbnailSmall,
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
      'thumbnail_small': thumbnailSmall,
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
      thumbnailData: map['thumbnail_data'] as Uint8List?,
      thumbnailSmall: map['thumbnail_small'] as Uint8List?,
    );
  }
}
