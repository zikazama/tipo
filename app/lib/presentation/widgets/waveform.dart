import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bar waveform. Pass live levels (0..1) while recording, or a seed to draw a
/// stable shape for an attached clip.
class Waveform extends StatelessWidget {
  const Waveform({super.key, this.levels, this.seed = 7, this.bars = 36, this.color, this.height = 36});
  final List<double>? levels;
  final int seed;
  final int bars;
  final Color? color;
  final double height;

  List<double> _resolve() {
    final live = levels;
    if (live != null) {
      final tail = live.length > bars ? live.sublist(live.length - bars) : live;
      return [...List.filled(bars - tail.length, 0.06), ...tail];
    }
    final rnd = math.Random(seed);
    return List.generate(bars, (i) {
      final envelope = math.sin(math.pi * (i + 1) / (bars + 1));
      return (0.25 + 0.75 * rnd.nextDouble()) * (0.35 + 0.65 * envelope);
    });
  }

  @override
  Widget build(BuildContext context) {
    final values = _resolve();
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final v in values)
              Expanded(
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 3,
                    height: math.max(3, height * v.clamp(0, 1)),
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
