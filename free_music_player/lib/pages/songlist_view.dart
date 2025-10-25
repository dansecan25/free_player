import 'dart:typed_data';
import 'package:flutter/material.dart';
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
  final int itemsPerPage = 12;
  bool isReversed = false; // for rendering order inversion

  @override
  void initState() {
    super.initState();
    filteredSongs = List.from(widget.songs);
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

  void _initializeVisibleSongs() {
    List<Song> songsToRender =
        isReversed ? filteredSongs.reversed.toList() : filteredSongs;
    visibleSongs = songsToRender.take(itemsPerPage).toList();
  }

  void _loadMoreSongs() {
    setState(() {
      isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      List<Song> songsToRender =
          isReversed ? filteredSongs.reversed.toList() : filteredSongs;
      final nextItems =
          songsToRender.skip(visibleSongs.length).take(itemsPerPage).toList();

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
      _initializeVisibleSongs();
      _scrollController.jumpTo(0); // scroll to top after search
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlistProvider =
        Provider.of<PlaylistProvider>(context, listen: false);

    return Column(
      children: [
        // Header: Search + invert order button
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
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    isReversed = !isReversed;
                    _initializeVisibleSongs();
                    _scrollController.jumpTo(0);
                  });
                },
                icon: const Icon(Icons.swap_vert),
                tooltip: 'Invert display order',
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
              Uint8List? albumImage = song.albumArtImagePathBytes;

              return ListTile(
                title: Text(song.songName),
                subtitle: Text(song.artistName),
                leading: albumImage != null
                    ? Image.memory(
                        albumImage,
                        width: 75,
                        height: 90,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.music_note, size: 70),
                onTap: () => widget.onSongTap(song, index),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await playlistProvider.deleteSong(context, song, index);

                      setState(() {
                        widget.songs.removeWhere(
                          (s) => s.audioPath.path == song.audioPath.path,
                        );
                        _filterSongs(searchQuery); // Refresh filtered list
                      });
                    }
                  },
                  itemBuilder: (context) => const [
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
              );
            },
          ),
        ),
      ],
    );
  }
}
