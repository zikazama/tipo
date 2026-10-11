import 'package:flutter/material.dart';

import '../../core/theme.dart';

export 'brand.dart' show TipoLogoMark, Wordmark;

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.band, this.score, this.large = false});
  final String band;
  final int? score;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fill = context.bandFill(band);
    final ink = context.bandText(band);
    final label = score == null ? band.toUpperCase() : '${band.toUpperCase()} $score';
    return Semantics(
      label: 'Priority $band${score == null ? '' : ', score $score'}',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: large ? Space.md : Space.sm, vertical: large ? 6 : 4),
          decoration: BoxDecoration(
            color: fill.withValues(alpha: context.isDark ? 0.18 : 0.14),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: fill.withValues(alpha: 0.75)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: fill, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontFamily: bodyFont, color: ink, fontSize: large ? 12.5 : 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

String credibilityBand(int score) => score >= 70 ? 'low' : score >= 40 ? 'medium' : 'critical';

class CredibilityBadge extends StatelessWidget {
  const CredibilityBadge({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final label = score >= 70 ? 'Credible' : score >= 40 ? 'Mixed' : 'Low credibility';
    final band = credibilityBand(score);
    final fill = context.bandFill(band);
    final ink = context.bandText(band);
    return Semantics(
      label: '$label, $score out of 100',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 4),
          decoration: BoxDecoration(color: fill.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.pill)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(score >= 40 ? Icons.verified_rounded : Icons.gpp_maybe_rounded, size: 13, color: ink),
              const SizedBox(width: 4),
              Text('$label $score', style: TextStyle(fontFamily: bodyFont, color: ink, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal 0–100 meter with an animated fill.
class CredibilityMeter extends StatelessWidget {
  const CredibilityMeter({super.key, required this.score, this.width = 72, this.showValue = true});
  final int score;
  final double width;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final fill = context.bandFill(credibilityBand(score));
    return Semantics(
      label: 'Credibility $score out of 100',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: Stack(
                  children: [
                    Positioned.fill(child: ColoredBox(color: context.line)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: score.clamp(0, 100) / 100),
                      duration: Motion.slow,
                      curve: Motion.curve,
                      builder: (context, value, _) => FractionallySizedBox(widthFactor: value, child: ColoredBox(color: fill)),
                    ),
                  ],
                ),
              ),
            ),
            if (showValue) ...[
              const SizedBox(width: 6),
              Text('$score', style: TextStyle(fontFamily: bodyFont, fontSize: 12, fontWeight: FontWeight.w700, color: context.bandText(credibilityBand(score)))),
            ],
          ],
        ),
      ),
    );
  }
}

/// Incident lifecycle as the operator sees it.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.alertSent = false});
  final String status;
  final bool alertSent;

  @override
  Widget build(BuildContext context) {
    final (label, icon, band) = switch (status) {
      'approved' => (alertSent ? 'Alert sent' : 'Approved', Icons.campaign_rounded, 'low'),
      'rejected' => ('Rejected', Icons.block_rounded, 'critical'),
      _ => ('Awaiting operator', Icons.hourglass_top_rounded, 'medium'),
    };
    final ink = context.bandText(band);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 4),
      decoration: BoxDecoration(
        color: context.bandFill(band).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: ink),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: bodyFont, color: ink, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class HazardAvatar extends StatelessWidget {
  const HazardAvatar({super.key, required this.hazard, required this.band, this.size = 40});
  final String hazard;
  final String band;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = context.bandFill(band);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.md)),
      child: Icon(hazardIcon(hazard), color: context.bandText(band), size: size * 0.55, semanticLabel: hazardLabel(hazard)),
    );
  }
}
