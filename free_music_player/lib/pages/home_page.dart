
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:free_music_player/components/my_drawer.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:free_music_player/pages/songlist_view.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String playlistSelected = "";
  List<Song> currentPlaylistSongs = [];
  List<Song> filteredSongs = [];
  String title = "Playlists";
  late final PlaylistProvider playlistProvider;
  bool songSelected = false;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      playlistProvider.setSongList();
    });
  }

  void goToSong(Song songObject, int songIndex) {
    playlistProvider.currentSongList = currentPlaylistSongs;
    if(songObject.songName != currentPlaylistSongs[songIndex].songName){
      for (int i=0;i<currentPlaylistSongs.length;i++){
        if(songObject.songName==currentPlaylistSongs[i].songName){
          playlistProvider.currentSongIndex = i;
          break;
        }
      }
    }else{
      playlistProvider.currentSongIndex = songIndex;
    }
    playlistProvider.setSongPlaying(songObject,songIndex);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SongPage(songObject: songObject)),
    );
  }

  void filterSongs(String query) {
    setState(() {
      searchQuery = query;
      filteredSongs = currentPlaylistSongs
          .where((song) =>
              song.songName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(title)),
      drawer: const MyDrawer(),
      body: Consumer<PlaylistProvider>(
        builder: (context, value, child) {
          final List<Playlist> playlistList = value.playlists;

          // Obtain the selected playlist
          if (playlistSelected != "") {
            for (Playlist entity in value.playlists) {
              if (entity.playlistName == playlistSelected) {
                currentPlaylistSongs = entity.playlistSongs!;
              }
            }
            // Initialize filteredSongs for search
            if (filteredSongs.isEmpty || searchQuery.isEmpty) {
              filteredSongs = currentPlaylistSongs;
            }
          }

          if (playlistSelected == "") {
            // Show playlists
            if (playlistList.isEmpty) {
              return const Center(
                child: Text(
                  "No playlists saved",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              );
            } else {
              return ListView.builder(
                itemCount: playlistList.length,
                itemBuilder: (context, index) {
                  final String playlist = playlistList[index].playlistName;
                  return ListTile(
                    title: Text("Playlist Name: $playlist"),
                    subtitle: FutureBuilder<int>(
                        future: value.countSongs(playlistList[index].directoryPath),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text("Counting songs...");
                          } else if (snapshot.hasError) {
                            return const Text("Error counting");
                          } else {
                            return Text("${snapshot.data ?? 0} songs");
                          }
                        },
                      ),
                    onTap: () async {
                      setState(() {
                        playlistSelected = playlist;
                        title = "Playlist: $playlist";
                      });

                      // Now run the async part *after* setState
                      final songs = await value.setSongsForPlaylist(playlistList[index].directoryPath);
                      setState(() {
                        playlistList[index].setSongs(songs);
                      });
                    }

                  );
                },
              );
            }
          } else {
            // Show songs of selected playlist with search bar
            return SongListView(
              songs: currentPlaylistSongs,
              onSongTap: (song, index) => goToSong(song, index),
            );
          }
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (playlistSelected != "")
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: FloatingActionButton(
                heroTag: "back_button",
                onPressed: () {
                  setState(() {
                    playlistSelected = "";
                    currentPlaylistSongs = [];
                    filteredSongs = [];
                    title = "Playlists";
                  });
                },
                tooltip: "Back to playlists",
                child: const Icon(Icons.arrow_back),
              ),
            ),
          FloatingActionButton(
            heroTag: "refresh_button",
            onPressed: () {
              Provider.of<PlaylistProvider>(
                context,
                listen: false,
              ).setSongList();
              setState(() {
                playlistSelected = "";
                currentPlaylistSongs = [];
                filteredSongs = [];
              });
            },
            tooltip: "Refresh playlists",
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(0.0),
        child: MediaControls(),
      ),
    );
  }
}
