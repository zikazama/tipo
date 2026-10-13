import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'citizen_layout.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: TipoColors.orange.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, size: 30, color: context.link),
              ),
              const SizedBox(height: Space.lg),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Space.sm),
              Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.muted)),
              if (action != null) ...[const SizedBox(height: Space.lg), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry, this.title = 'Posko belum terhubung'});
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: title,
      body: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Coba lagi · Retry')),
    );
  }
}

/// Pulsing placeholder block for loading lists.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 72, this.radius = Radii.lg});
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(color: context.line.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(widget.radius)),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.step});
  final String title;
  final Widget? trailing;
  final int? step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        children: [
          if (step != null) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: TipoColors.navy, shape: BoxShape.circle),
              child: Text('$step', style: const TextStyle(fontFamily: headingFont, color: TipoColors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: Space.sm + 2),
          ],
          Expanded(child: Semantics(header: true, child: Text(title, style: CitizenLayout.sectionTitleStyle(context)))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Relative time in Indonesian-first short form, e.g. "5 mnt lalu".
String timeAgo(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final diff = (now ?? DateTime.now()).toUtc().difference(at.toUtc());
  if (diff.inSeconds < 45) return 'baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  return '${diff.inDays} hari lalu';
}
