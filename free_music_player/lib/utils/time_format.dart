/// Formats a playback position as m:ss.
String formatPlaybackTime(Duration duration) {
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inMinutes}:$seconds';
}
