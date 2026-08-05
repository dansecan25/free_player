import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/pages/home_page.dart';
import 'package:free_music_player/services/audio_handler.dart';
import 'package:free_music_player/services/playback_state_service.dart';
import 'package:free_music_player/services/theme_service.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request MANAGE_EXTERNAL_STORAGE permission on Android 11+
  if (await Permission.manageExternalStorage.isDenied) {
    await Permission.manageExternalStorage.request();
  }

  // Initialize playback state service for persistence
  final stateService = await PlaybackStateService.initialize();

  // Initialize audio service with proper configuration
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.free_music_player.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: false, // Must be false when androidStopForegroundOnPause is false
      androidStopForegroundOnPause: false, // Keep service alive when paused
    ),
  );

  // Create playlist provider with state service
  final playlistProvider = PlaylistProvider(audioHandler, stateService: stateService);

  // Inject the provider into the handler for skip controls
  audioHandler.setPlaylistProvider(playlistProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeService()),
        ChangeNotifierProvider.value(value: playlistProvider),
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
