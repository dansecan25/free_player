import 'package:flutter/widgets.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:provider/provider.dart';

/// Calls [reloadSongs] when the library changes (songs added or deleted by a
/// rescan or from another screen), so open lists never show stale songs.
mixin LibraryReloadMixin<T extends StatefulWidget> on State<T> {
  late final PlaylistProvider _library = context.read<PlaylistProvider>();
  late int _seenRevision;

  Future<void> reloadSongs();

  @override
  void initState() {
    super.initState();
    _seenRevision = _library.libraryRevision;
    _library.addListener(_onLibraryChanged);
  }

  @override
  void dispose() {
    _library.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (_library.libraryRevision == _seenRevision) return;
    _seenRevision = _library.libraryRevision;
    reloadSongs();
  }

  /// Pull-to-refresh: rescan the folder, then reload this list.
  Future<void> refreshFromDisk() async {
    await _library.refreshLibrary();
    _seenRevision = _library.libraryRevision;
    await reloadSongs();
  }
}
