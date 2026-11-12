import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:free_music_player/models/song.dart';

/// Rounded square thumbnail for a song, with a note icon when there's no art.
class ArtworkThumbnail extends StatelessWidget {
  final Song song;
  final double size;

  const ArtworkThumbnail({super.key, required this.song, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: song.albumArtNotifier,
      builder: (context, bytes, _) => ArtworkImage(bytes: bytes, size: size),
    );
  }
}

/// Artwork from raw bytes, or a placeholder. Decodes at the displayed size.
class ArtworkImage extends StatelessWidget {
  final Uint8List? bytes;
  final double size;
  final double radius;

  const ArtworkImage({super.key, required this.bytes, this.size = 52, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: bytes == null
            ? ColoredBox(
                color: scheme.primaryContainer,
                child: Icon(Icons.music_note,
                    size: size * 0.5, color: scheme.onPrimaryContainer),
              )
            : RepaintBoundary(
                child: Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                  cacheWidth: pixels,
                  gaplessPlayback: true,
                ),
              ),
      ),
    );
  }
}
