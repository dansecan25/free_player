import 'package:flutter/material.dart';
import 'package:free_music_player/components/my_drawer.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:free_music_player/pages/song_page.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String playlistSelected = "";
  List<Song> currentPlaylistSongs = [];
  String title = "Playlists";
  late final dynamic playlistProvider;
  bool songSelected = false;

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
    playlistProvider.currentSongIndex = songIndex;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SongPage(songObject: songObject)),
    );
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
          //obtain the selected playlist
          if (playlistSelected != "") {
            for (Playlist entity in value.playlists) {
              //goes throug all plyalists
              if (entity.playlistName == playlistSelected) {
                //if the name is equal to the selected one
                currentPlaylistSongs =
                    entity.playlistSongs; //choose the song list
              }
            }
          }
          return (playlistSelected == ""
              ? (playlistList.isEmpty
                  ? (Center(
                    child: Text(
                      "No playlists saved",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ))
                  : (ListView.builder(
                    itemCount: playlistList.length,
                    itemBuilder: (context, index) {
                      //final Song song = playlistList[index];
                      final String playlist = playlistList[index].playlistName;
                      return ListTile(
                        title: Text("Playlist Name: $playlist"),
                        subtitle: Text(
                          "${playlistList[index].playlistSongs.length} songs",
                        ),
                        onTap:
                            () => {
                              setState(() {
                                playlistSelected = playlist;
                                title = "Playlist: $playlist";
                              }),
                            },
                      );
                    },
                  )))
              : ListView.builder(
                itemCount: currentPlaylistSongs.length,
                itemBuilder: (context, index) {
                  final String songString =
                      (currentPlaylistSongs[index]).songName;
                  final String authorName =
                      (currentPlaylistSongs[index]).artistName;
                  //final String pathName =
                  // (currentPlaylistSongs[index]).audioPath.path;
                  return ListTile(
                    title: Text(songString),
                    subtitle: Text(authorName),
                    //leading: Image.asset(song.albumArtImagePath)
                    onTap: () => {goToSong(currentPlaylistSongs[index], index)},
                  );
                },
              ));
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (playlistSelected != "") // show back button conditionally
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: FloatingActionButton(
                heroTag: "back_button", // Needed to avoid Hero tag conflict
                onPressed: () {
                  setState(() {
                    playlistSelected = "";
                    currentPlaylistSongs = [];
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
              });
            },
            tooltip: "Refresh playlists",
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
