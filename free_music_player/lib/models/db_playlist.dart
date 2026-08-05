/// A playlist stored in the PLAYLISTS table (not tied to any directory).
class DbPlaylist {
  final int id;
  final String name;

  const DbPlaylist({required this.id, required this.name});

  factory DbPlaylist.fromMap(Map<String, dynamic> map) {
    return DbPlaylist(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }
}
