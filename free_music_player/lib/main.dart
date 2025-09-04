import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/pages/home_page.dart';
import 'package:free_music_player/services/audio_handler.dart';
import 'package:free_music_player/services/theme_service.dart';
import 'package:free_music_player/models/playlist_provider.dart'; // Import PlaylistProvider
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.free_music_player.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeService()),
        ChangeNotifierProvider(
          create: (context) => PlaylistProvider(audioHandler),
        ), // Add PlaylistProvider
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  final String versionNumber = "0.0.1";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player Overloaded',
      theme: Provider.of<ThemeService>(context).themeData,
      home: HomePage(),
    );
  }
}
