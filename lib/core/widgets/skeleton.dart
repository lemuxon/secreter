import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

/// Iskelet yukleme (skeleton) bilesenleri — harici paket YOK.
/// Nabiz (pulse) animasyonu tek controller ile calisir ve dispose edilir.

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Erisilebilirlik: animasyon kapaliysa sabit soluk goster
    if (MediaQuery.of(context).disableAnimations) {
      return Opacity(opacity: 0.6, child: widget.child);
    }
    return FadeTransition(opacity: _c, child: widget.child);
  }
}

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const SkeletonBox(
      {super.key, required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Sohbet listesi iskeleti (avatar + iki satir) — yukleme sirasinda.
class ChatListSkeleton extends StatelessWidget {
  const ChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Pulse(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const SkeletonBox(width: 48, height: 48, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 90.0 + (i % 3) * 40, height: 14),
                    const SizedBox(height: 8),
                    SkeletonBox(width: 150.0 + (i % 2) * 60, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mesaj listesi iskeleti (sag/sol donusumlu balonlar).
class MessageListSkeleton extends StatelessWidget {
  final double topPadding;
  const MessageListSkeleton({super.key, this.topPadding = 0});

  @override
  Widget build(BuildContext context) {
    const widths = [180.0, 120.0, 220.0, 150.0, 200.0, 100.0];
    return _Pulse(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: topPadding + 12, left: 14, right: 14),
        itemCount: widths.length,
        itemBuilder: (_, i) {
          final mine = i.isOdd;
          return Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: SkeletonBox(
                  width: widths[i], height: 38 + (i % 2) * 14, radius: 14),
            ),
          );
        },
      ),
    );
  }
}
