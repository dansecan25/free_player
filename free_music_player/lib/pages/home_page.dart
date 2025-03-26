import 'package:flutter/material.dart';
import 'package:free_music_player/components/my_drawer.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/models/song.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlaylistProvider>(context, listen: false).setSongList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text("Playlist")),
      drawer: const MyDrawer(),
      body: Consumer<PlaylistProvider>(
        builder: (context, value, child) {
          //final List<List<Song>> playlistList = value.songList;
          final List<String> playlistList = value.playlistNames;
          return playlistList.isEmpty
              ? Center(
                child: Text(
                  "No playlists saved",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              )
              : ListView.builder(
                itemCount: playlistList.length,
                itemBuilder: (context, index) {
                  //final Song song = playlistList[index];
                  final String song = playlistList[index];
                  return ListTile(
                    title: Text("Song Name: $song!"),
                    subtitle: Text("Unknown artist"),
                  );
                },
              );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Refresh the song list by calling setSongList
          Provider.of<PlaylistProvider>(context, listen: false).setSongList();
        },
        child: Icon(Icons.refresh),
      ),
    );
  }
}
