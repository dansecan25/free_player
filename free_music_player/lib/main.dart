import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:free_music_player/constants/app_info.dart';
import 'package:free_music_player/models/playlist_provider.dart';
import 'package:free_music_player/pages/home_page.dart';
import 'package:free_music_player/services/app_update_service.dart';
import 'package:free_music_player/services/audio_handler.dart';
import 'package:free_music_player/services/playback_state_service.dart';
import 'package:free_music_player/services/theme_service.dart';
import 'package:free_music_player/themes/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reading the music folder needs "All files access" on Android 11+.
  if (await Permission.manageExternalStorage.isDenied) {
    await Permission.manageExternalStorage.request();
  }

  final stateService = await PlaybackStateService.initialize();
  final audioHandler = await AudioService.init(
    builder: AudioPlayerHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: AppInfo.audioNotificationChannelId,
      androidNotificationChannelName: AppInfo.audioNotificationChannelName,
      androidNotificationOngoing: false, // must be false with androidStopForegroundOnPause false
      androidStopForegroundOnPause: false, // keep the service alive while paused
    ),
  );

  final playlistProvider = PlaylistProvider(audioHandler, stateService: stateService);
  audioHandler.setPlaylistProvider(playlistProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService(stateService.preferences)),
        ChangeNotifierProvider(create: (_) => AppUpdateService(stateService.preferences)),
        ChangeNotifierProvider.value(value: playlistProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppUpdateService>().checkForUpdates();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in the foreground: pick up songs added or deleted meanwhile, and
  /// look for an app update (throttled inside the service).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<PlaylistProvider>().refreshLibrary();
    context.read<AppUpdateService>().checkForUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.watch<ThemeService>().mode,
      home: const HomePage(),
    );
  }
}
