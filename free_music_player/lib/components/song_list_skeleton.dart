import 'package:flutter/material.dart';

/// Pulsing placeholder rows shown while a song list loads. Matches the real
/// tile layout so nothing jumps when the songs arrive.
class SongListSkeleton extends StatefulWidget {
  const SongListSkeleton({super.key});

  @override
  State<SongListSkeleton> createState() => _SongListSkeletonState();
}

class _SongListSkeletonState extends State<SongListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    // Keep still when the system asks for reduced motion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 0.5;
      } else {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = base.withAlpha((20 + _controller.value * 30).round());
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          itemBuilder: (_, _) => _SkeletonTile(color: color),
        );
      },
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  final Color color;
  const _SkeletonTile({required this.color});

  Widget _bar(double height, double? width) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(13, double.infinity),
                const SizedBox(height: 8),
                _bar(11, 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
