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
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (playlistSelected == "")
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: "Add Playlist",
              onPressed: () async {
                // This will later open a dialog or form to add a playlist to DB
                showDialog(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text("Add New Playlist"),
                      content: const Text("Playlist creation will be available soon."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("OK"),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
      drawer: const MyDrawer(),
      body: Consumer<PlaylistProvider>(
        builder: (context, value, child) {
          final List<Playlist> playlistList = value.playlists;

          if (playlistSelected != "") {
            // --- Playlist songs view ---
            for (Playlist entity in value.playlists) {
              if (entity.playlistName == playlistSelected) {
                currentPlaylistSongs = entity.playlistSongs!;
              }
            }
            if (filteredSongs.isEmpty || searchQuery.isEmpty) {
              filteredSongs = currentPlaylistSongs;
            }

            return SongListView(
              songs: currentPlaylistSongs,
              onSongTap: (song, index) => goToSong(song, index),
            );
          } else {
            // --- Playlist list view ---
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
                  final playlist = playlistList[index];
                  return Column(
                    children: [
                      ListTile(
                        title: Text(playlist.playlistName),
                        subtitle: FutureBuilder<int>(
                          future: value.countSongs(playlist.directoryPath),
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
                            playlistSelected = playlist.playlistName;
                            title = "Playlist: ${playlist.playlistName}";
                          });
                          final songs = await value.setSongsForPlaylist(playlist.directoryPath);
                          setState(() {
                            playlist.setSongs(songs);
                          });
                        },
                      ),
                      const Divider(
                        color: Colors.grey, // light gray line
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16,
                      ),
                    ],
                  );
                },
              );
            }
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
