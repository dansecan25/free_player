import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:free_music_player/components/add_to_playlist_dialog.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:provider/provider.dart';

class SongListView extends StatefulWidget {
  final List<Song> songs;
  final Function(Song, int) onSongTap; // callback to navigate to song page

  const SongListView({
    super.key,
    required this.songs,
    required this.onSongTap,
  });

  @override
  State<SongListView> createState() => _SongListViewState();
}

class _SongListViewState extends State<SongListView> {
  final ScrollController _scrollController = ScrollController();
  List<Song> filteredSongs = [];
  List<Song> visibleSongs = [];
  bool isLoadingMore = false;
  String searchQuery = '';
  bool isReversed = false;
  final int itemsPerPage = 10; // matches PlaylistProvider's artwork batch size

  @override
  void initState() {
    super.initState();
    _loadSortState();
    filteredSongs = widget.songs;
    if (isReversed) {
      filteredSongs = filteredSongs.reversed.toList();
    }
    _initializeVisibleSongs();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          visibleSongs.length < filteredSongs.length) {
        _loadMoreSongs();
      }
    });
  }

  void _loadSortState() {
    final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
    if (playlistProvider.stateService != null) {
      isReversed = playlistProvider.stateService!.getSortReversed();
    }
  }

  void _initializeVisibleSongs() {
    visibleSongs = filteredSongs.take(itemsPerPage).toList();
  }

  void _loadMoreSongs() {
    setState(() {
      isLoadingMore = true;
    });

    // Schedule after the current frame instead of an arbitrary delay --
    // avoids doing the list update mid-scroll-gesture without adding a
    // fixed stall on top of it.
    Future.microtask(() {
      if (!mounted) return;
      final nextItems =
          filteredSongs.skip(visibleSongs.length).take(itemsPerPage).toList();
      setState(() {
        visibleSongs.addAll(nextItems);
        isLoadingMore = false;
      });
    });
  }

  void _filterSongs(String query) {
    setState(() {
      searchQuery = query;
      filteredSongs = widget.songs
          .where((song) =>
              song.songName.toLowerCase().contains(query.toLowerCase()))
          .toList();
      if (isReversed) {
        filteredSongs = filteredSongs.reversed.toList();
      }
      _initializeVisibleSongs();
    });
  }

  void _toggleSortOrder() {
    setState(() {
      isReversed = !isReversed;
      filteredSongs = filteredSongs.reversed.toList();
      _initializeVisibleSongs();
      
      // Save sort state
      final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
      if (playlistProvider.stateService != null) {
        playlistProvider.stateService!.saveSortReversed(isReversed);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search songs...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: _filterSongs,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_vert, size: 28),
                tooltip: 'Reverse order',
                onPressed: _toggleSortOrder,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: visibleSongs.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == visibleSongs.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final song = visibleSongs[index];
              final dpr = MediaQuery.of(context).devicePixelRatio;

              return Column(
                children: [
                  ListTile(
                    title: Text(song.songName),
                    subtitle: Text(song.artistName),
                    leading: ValueListenableBuilder<Uint8List?>(
                      valueListenable: song.albumArtNotifier,
                      builder: (context, albumImage, _) {
                        if (albumImage == null) {
                          return const Icon(Icons.music_note, size: 48);
                        }
                        return RepaintBoundary(
                          child: Image.memory(
                            albumImage,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            cacheWidth: (48 * dpr).round(),
                            cacheHeight: (48 * dpr).round(),
                            gaplessPlayback: true,
                          ),
                        );
                      },
                    ),
                    onTap: () => widget.onSongTap(song, index),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) async {
                        if (value == 'add_to_playlist') {
                          await showAddToPlaylistDialog(context, song);
                        } else if (value == 'delete') {
                          await playlistProvider.deleteSong(context, song, index);

                          setState(() {
                            widget.songs.removeWhere(
                              (s) => s.audioPath.path == song.audioPath.path,
                            );
                            _filterSongs(searchQuery);
                          });
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'add_to_playlist',
                          child: Row(
                            children: [
                              Icon(Icons.playlist_add),
                              SizedBox(width: 8),
                              Text('Add to playlist'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete,
                                  color: Color.fromARGB(255, 255, 105, 94)),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Color(0x26000000),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
