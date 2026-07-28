import 'package:flutter/material.dart';
import 'package:free_music_player/components/media_controls.dart';
import 'package:free_music_player/components/my_drawer.dart';
import 'package:free_music_player/models/playlist.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/pages/playlist_songs_page.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PlaylistProvider playlistProvider;

  @override
  void initState() {
    super.initState();
    playlistProvider = Provider.of<PlaylistProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      playlistProvider.setSongList();
    });
  }

  void _openPlaylist(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistSongsPage(playlist: playlist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Playlists"),
        actions: [
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
          }

          return ListView.builder(
            itemCount: playlistList.length,
            itemBuilder: (context, index) {
              final playlist = playlistList[index];
              return Column(
                children: [
                  ListTile(
                    title: Text(playlist.playlistName),
                    subtitle: playlist.songCount != null
                        ? Text("${playlist.songCount} songs")
                        : FutureBuilder<int>(
                            future: value.countSongs(playlist.directoryPath),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Text("Counting songs...");
                              } else if (snapshot.hasError) {
                                return const Text("Error counting");
                              } else {
                                // Cache the count once we have it
                                if (snapshot.hasData) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    playlist.setSongCount(snapshot.data!);
                                  });
                                }
                                return Text("${snapshot.data ?? 0} songs");
                              }
                            },
                          ),
                    onTap: () => _openPlaylist(playlist),
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
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "refresh_button",
        onPressed: () {
          Provider.of<PlaylistProvider>(context, listen: false).setSongList();
        },
        tooltip: "Refresh playlists",
        child: const Icon(Icons.refresh),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(0.0),
        child: MediaControls(),
      ),
    );
  }
}
