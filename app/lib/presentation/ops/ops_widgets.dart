import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Dark surface used for every console pane.
class OpsPanel extends StatelessWidget {
  const OpsPanel({super.key, required this.child, this.padding = EdgeInsets.zero, this.color = TipoColors.navyPanel, this.border = true});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: border ? const Border(right: BorderSide(color: TipoColors.navyLine)) : null,
      ),
      child: child,
    );
  }
}

class PaneHeader extends StatelessWidget {
  const PaneHeader({super.key, required this.title, this.caption, this.trailing, this.icon});
  final String title;
  final String? caption;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.md, Space.sm),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: TipoColors.orangeSoft), const SizedBox(width: Space.sm)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: const TextStyle(fontFamily: headingFont, fontSize: 15, fontWeight: FontWeight.w600, color: TipoColors.text))),
                if (caption != null) Text(caption!, style: const TextStyle(fontSize: 12, color: TipoColors.muted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Small uppercase label above a block of detail content.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = TipoColors.muted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Semantics(
          header: true,
          child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: color)),
        ),
      );
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, required this.icon, this.accent = TipoColors.orangeSoft});
  final String value;
  final String label;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: TipoColors.navyRaised,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: TipoColors.navyLine),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: Space.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, fontSize: 17, color: TipoColors.text)),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TipoColors.muted, fontSize: 11.5)),
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

class Tag extends StatelessWidget {
  const Tag({super.key, required this.label, this.icon, this.color = TipoColors.muted, this.filled = false});
  final String label;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }
}

/// The four ADK agents, in pipeline order.
class AgentMeta {
  const AgentMeta(this.key, this.label, this.icon, this.color, this.role);
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String role;
}

const agents = [
  AgentMeta('intake', 'Intake', Icons.record_voice_over_rounded, TipoColors.info, 'Transcribe, translate, extract'),
  AgentMeta('verification', 'Verification', Icons.fact_check_rounded, TipoColors.lowOnDark, 'EXIF, BMKG, credibility'),
  AgentMeta('dedup', 'Dedup', Icons.merge_rounded, TipoColors.mediumOnDark, 'Embed and merge'),
  AgentMeta('triage', 'Triage', Icons.sort_rounded, TipoColors.orangeSoft, 'Priority, team, logistics'),
];

AgentMeta agentMeta(String key) => agents.firstWhere((a) => a.key == key, orElse: () => agents.first);

enum ToastTone { success, info, warning, error }

void showToast(BuildContext context, String message, {ToastTone tone = ToastTone.info, String? detail}) {
  final (icon, color) = switch (tone) {
    ToastTone.success => (Icons.check_circle_rounded, TipoColors.lowOnDark),
    ToastTone.warning => (Icons.warning_amber_rounded, TipoColors.mediumOnDark),
    ToastTone.error => (Icons.error_rounded, TipoColors.criticalOnDark),
    ToastTone.info => (Icons.info_rounded, TipoColors.info),
  };
  final wide = MediaQuery.sizeOf(context).width > 720;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        width: wide ? 440 : null,
        backgroundColor: TipoColors.navyRaised,
        elevation: 8,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md), side: BorderSide(color: color.withValues(alpha: 0.6))),
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: const TextStyle(color: TipoColors.text, fontWeight: FontWeight.w600)),
                  if (detail != null) Text(detail, style: const TextStyle(color: TipoColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
}
