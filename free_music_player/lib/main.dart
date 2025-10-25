import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/pages/home_page.dart';
import 'package:free_music_player/services/audio_handler.dart';
import 'package:free_music_player/services/theme_service.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  


  

  Future<void> requestBatteryOptimizationDisable() async {
    const platform = MethodChannel('battery_optimization');
    try {
      await platform.invokeMethod('disableBatteryOptimization');
    } catch (e) {
      print('Failed to disable battery optimization: $e');
    }
  }
  await requestBatteryOptimizationDisable();



  // Request MANAGE_EXTERNAL_STORAGE permission on Android 11+
  if (await Permission.manageExternalStorage.isDenied) {
    await Permission.manageExternalStorage.request();
  }

  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.free_music_player.channel.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
    ),
  );
  final playlistProvider = PlaylistProvider(audioHandler);

  // Now inject the provider into the handler
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
