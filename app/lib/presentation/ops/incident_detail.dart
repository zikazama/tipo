import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/insights.dart';
import '../../domain/models.dart';
import '../widgets/badges.dart';
import '../widgets/states.dart';
import '../widgets/waveform.dart';
import 'incident_map.dart' show isSuspect;
import 'ops_widgets.dart';
import 'sitrep_page.dart';

class IncidentDetail extends StatelessWidget {
  const IncidentDetail({
    super.key,
    required this.incident,
    required this.snap,
    required this.acting,
    required this.mediaUrl,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onOpenSitrep,
    this.onClose,
  });
  final Incident? incident;
  final BoardSnapshot snap;
  final bool acting;
  final String Function(String) mediaUrl;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onOpenSitrep;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    if (i == null) {
      return const OpsPanel(
        border: false,
        color: TipoColors.navy,
        child: EmptyState(
          icon: Icons.touch_app_rounded,
          title: 'Select an incident',
          body: 'Pick a ticket from the queue or a marker on the map to see evidence, reasoning, and the alert gate.',
        ),
      );
    }
    final reports = snap.reports.where((r) => i.reportIds.contains(r.id)).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    final alerted = snap.notifications.where((n) => n.type == 'nearby_alert' && n.incidentId == i.id).length;
    return Container(
      color: TipoColors.navy,
      child: DefaultTabController(
        length: 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(incident: i, onClose: onClose),
            if (isSuspect(i)) _HoaxBanner(incident: i),
            if (i.decision != null) _DecisionBanner(incident: i, alerted: alerted),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: TipoColors.text,
              unselectedLabelColor: TipoColors.muted,
              indicatorColor: TipoColors.orange,
              indicatorWeight: 3,
              dividerColor: TipoColors.navyLine,
              labelStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: TextStyle(fontFamily: bodyFont, fontWeight: FontWeight.w500, fontSize: 13),
              padding: EdgeInsets.symmetric(horizontal: Space.sm),
              tabs: [
                Tab(text: 'Summary'),
                Tab(text: 'Evidence'),
                Tab(text: 'Credibility'),
                Tab(text: 'Priority'),
                Tab(text: 'Logistics'),
                Tab(text: 'Sitrep'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SummaryTab(incident: i, reports: reports),
                  _EvidenceTab(reports: reports, mediaUrl: mediaUrl),
                  _CredibilityTab(incident: i),
                  _PriorityTab(incident: i),
                  _LogisticsTab(incident: i),
                  _SitrepTab(incident: i, onOpen: onOpenSitrep),
                ],
              ),
            ),
            _ActionFooter(incident: i, acting: acting, onApprove: onApprove, onReject: onReject, onEdit: onEdit),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.incident, this.onClose});
  final Incident incident;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.sm, Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HazardAvatar(hazard: i.hazardType, band: isSuspect(i) ? 'critical' : i.priorityBand, size: 48),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i.id} · ${timeAgo(i.createdAt)}', style: const TextStyle(color: TipoColors.muted, fontSize: 11.5)),
                const SizedBox(height: 2),
                Semantics(header: true, child: Text(i.title, style: displayStyle(size: 21, color: TipoColors.text))),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.xs + 2,
                  runSpacing: Space.xs + 2,
                  children: [
                    PriorityBadge(band: i.priorityBand, score: i.priorityScore, large: true),
                    CredibilityBadge(score: i.credibility),
                    StatusPill(status: i.status, alertSent: i.decision?.alertSent ?? false),
                  ],
                ),
              ],
            ),
          ),
          if (onClose != null) IconButton(tooltip: 'Close details', onPressed: onClose, icon: const Icon(Icons.close_rounded, color: TipoColors.muted)),
        ],
      ),
    );
  }
}

class _HoaxBanner extends StatelessWidget {
  const _HoaxBanner({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final risks = incident.credibilityReasons.where((r) => reasonTone(r) == ReasonTone.risk).toList();
    final shown = risks.isEmpty ? incident.credibilityReasons.take(2).toList() : risks.take(3).toList();
    return Semantics(
      container: true,
      label: 'Warning: possible hoax',
      child: Container(
        margin: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF3A1622), Color(0xFF2A1A28)]),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: TipoColors.criticalOnDark, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: TipoColors.criticalOnDark),
                SizedBox(width: Space.sm),
                Expanded(
                  child: Text('Possible hoax. Do not alert yet.', style: TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, color: TipoColors.text, fontSize: 14.5)),
                ),
              ],
            ),
            const SizedBox(height: Space.xs + 2),
            Text(
              'Credibility ${incident.credibility}/100. Priority was cut to ${incident.priorityScore} because the evidence does not hold up.',
              style: const TextStyle(color: TipoColors.text, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: Space.sm),
            for (final r in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.close_rounded, size: 15, color: TipoColors.criticalOnDark)),
                    const SizedBox(width: Space.xs + 2),
                    Expanded(child: Text(r, style: const TextStyle(color: TipoColors.text, fontSize: 12.5, height: 1.4))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DecisionBanner extends StatelessWidget {
  const _DecisionBanner({required this.incident, required this.alerted});
  final Incident incident;
  final int alerted;

  @override
  Widget build(BuildContext context) {
    final d = incident.decision!;
    final approved = d.action == 'approve';
    final rejected = d.action == 'reject';
    if (!approved && !rejected) return const SizedBox.shrink();
    final color = approved ? TipoColors.lowOnDark : TipoColors.muted;
    final title = approved
        ? (d.alertSent ? 'Alert sent to $alerted nearby device${alerted == 1 ? '' : 's'}' : 'Approved without a public alert')
        : 'Rejected. No public alert.';
    final when = timeAgo(d.decidedAt);
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(approved ? Icons.verified_user_rounded : Icons.block_rounded, color: color),
          const SizedBox(width: Space.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: TipoColors.text)),
                Text(
                  '${d.operatorName.isEmpty ? 'Operator' : d.operatorName}${when.isEmpty ? '' : ' · $when'}${d.note.isEmpty ? '' : ' · ${d.note}'}',
                  style: const TextStyle(color: TipoColors.muted, fontSize: 12),
                ),
                if (incident.updatesSinceDecision > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(
                      '${incident.updatesSinceDecision} new report${incident.updatesSinceDecision == 1 ? '' : 's'} since this decision.',
                      style: const TextStyle(color: TipoColors.orangeSoft, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabList extends StatelessWidget {
  const _TabList({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xl), children: children);
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.incident, required this.reports});
  final Incident incident;
  final List<CitizenReport> reports;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    final languages = {for (final r in reports) if (r.language.isNotEmpty) languageLabel(r.language)};
    final signals = [
      ...i.credibilityReasons.where((r) => reasonTone(r) == ReasonTone.support).take(1),
      ...i.priorityReasons.take(1),
    ];
    return _TabList(
      children: [
        Text(i.summary, style: const TextStyle(color: TipoColors.text, height: 1.5, fontSize: 14)),
        const SizedBox(height: Space.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          childAspectRatio: 2.6,
          children: [
            StatTile(value: '${i.peopleAffected}', label: 'people affected', icon: Icons.groups_rounded),
            StatTile(value: '${i.trapped}', label: 'trapped', icon: Icons.sos_rounded, accent: i.trapped > 0 ? TipoColors.criticalOnDark : TipoColors.muted),
            StatTile(value: '${i.reportIds.length}', label: 'reports merged', icon: Icons.forum_rounded, accent: TipoColors.info),
            StatTile(value: 'S${i.severity}', label: 'severity (of 5)', icon: Icons.speed_rounded, accent: bandColor(i.priorityBand)),
          ],
        ),
        if (i.vulnerable.isNotEmpty || i.needs.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          const Eyebrow('Who and what'),
          Wrap(
            spacing: Space.xs + 2,
            runSpacing: Space.xs + 2,
            children: [
              for (final v in i.vulnerable) Tag(label: v, icon: Icons.accessible_rounded, color: TipoColors.criticalOnDark),
              for (final n in i.needs) Tag(label: n, icon: Icons.inventory_2_rounded, color: TipoColors.orangeSoft),
            ],
          ),
        ],
        if (signals.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          const Eyebrow('Key signals'),
          for (final s in signals) _Reason(text: s, tone: reasonTone(s) == ReasonTone.risk ? ReasonTone.risk : ReasonTone.support),
        ],
        const SizedBox(height: Space.lg),
        const Eyebrow('Sources'),
        Wrap(
          spacing: Space.xs + 2,
          runSpacing: Space.xs + 2,
          children: [
            for (final c in i.channels) Tag(label: channelLabel(c), icon: _channelIcon(c), color: TipoColors.info),
            for (final l in languages) Tag(label: l, icon: Icons.translate_rounded, color: TipoColors.muted),
          ],
        ),
        if (i.suggestedTeam != null) ...[
          const SizedBox(height: Space.lg),
          const Eyebrow('Suggested team'),
          _TeamRow(team: i.suggestedTeam!, primary: true),
        ],
      ],
    );
  }
}

IconData _channelIcon(String channel) => switch (channel) {
      'voice' => Icons.mic_rounded,
      'whatsapp_sim' => Icons.chat_rounded,
      'petabencana' => Icons.public_rounded,
      _ => Icons.phone_android_rounded,
    };

class _Reason extends StatelessWidget {
  const _Reason({required this.text, required this.tone});
  final String text;
  final ReasonTone tone;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (tone) {
      ReasonTone.risk => (Icons.error_outline_rounded, TipoColors.criticalOnDark, 'Risk'),
      ReasonTone.support => (Icons.check_circle_outline_rounded, TipoColors.lowOnDark, 'Supports'),
      ReasonTone.neutral => (Icons.info_outline_rounded, TipoColors.muted, 'Context'),
    };
    return Semantics(
      label: '$label: $text',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: Space.sm),
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: TipoColors.navyPanel,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: Space.sm + 2),
              Expanded(child: Text(text, style: const TextStyle(color: TipoColors.text, fontSize: 13, height: 1.45))),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceTab extends StatelessWidget {
  const _EvidenceTab({required this.reports, required this.mediaUrl});
  final List<CitizenReport> reports;
  final String Function(String) mediaUrl;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const EmptyState(icon: Icons.photo_library_outlined, title: 'No evidence attached', body: 'Reports merged into this ticket will show their photos, voice notes, and EXIF checks here.');
    }
    final photos = reports.where((r) => r.photoUrl != null).length;
    final voices = reports.where((r) => r.audioUrl != null || r.channel == 'voice').length;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xl),
      itemCount: reports.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: Space.md),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            '${reports.length} reports · $photos photo${photos == 1 ? '' : 's'} · $voices voice note${voices == 1 ? '' : 's'}',
            style: const TextStyle(color: TipoColors.muted, fontSize: 12.5),
          );
        }
        return _EvidenceCard(report: reports[index - 1], mediaUrl: mediaUrl);
      },
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.report, required this.mediaUrl});
  final CitizenReport report;
  final String Function(String) mediaUrl;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final flags = evidenceFlags(r);
    final risky = flags.any((f) => f.risk);
    final spoken = r.transcript.isNotEmpty ? r.transcript : r.text;
    final voice = r.audioUrl != null || r.channel == 'voice';
    return Container(
      decoration: BoxDecoration(
        color: TipoColors.navyPanel,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: risky ? TipoColors.criticalOnDark.withValues(alpha: 0.7) : TipoColors.navyLine),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (r.photoUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    mediaUrl(r.photoUrl!),
                    fit: BoxFit.cover,
                    semanticLabel: 'Photo from ${r.id}',
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: TipoColors.navyRaised,
                      child: Center(child: Icon(Icons.broken_image_rounded, color: TipoColors.muted, size: 32)),
                    ),
                  ),
                  if (risky)
                    Positioned(
                      left: Space.sm,
                      top: Space.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 4),
                        decoration: BoxDecoration(color: TipoColors.critical, borderRadius: BorderRadius.circular(Radii.sm)),
                        child: const Text('CHECK PHOTO', style: TextStyle(color: TipoColors.white, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8)),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_channelIcon(r.channel), size: 16, color: TipoColors.info),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${channelLabel(r.channel)} · ${languageLabel(r.language)} · ${timeAgo(r.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: TipoColors.muted),
                      ),
                    ),
                    if (r.credibility != null) CredibilityMeter(score: r.credibility!, width: 44),
                  ],
                ),
                if (voice) ...[
                  const SizedBox(height: Space.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs + 2),
                    decoration: BoxDecoration(color: TipoColors.navyRaised, borderRadius: BorderRadius.circular(Radii.sm)),
                    child: Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded, size: 18, color: TipoColors.orangeSoft),
                        const SizedBox(width: Space.sm),
                        Expanded(child: Waveform(seed: r.id.hashCode, bars: 40, height: 24, color: TipoColors.orangeSoft)),
                      ],
                    ),
                  ),
                ],
                if (spoken.isNotEmpty) ...[
                  const SizedBox(height: Space.sm),
                  Text('“$spoken”', style: const TextStyle(color: TipoColors.text, fontSize: 13.5, height: 1.45, fontStyle: FontStyle.italic)),
                ],
                if (r.translationEn.isNotEmpty && r.translationEn != spoken) ...[
                  const SizedBox(height: Space.xs + 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.translate_rounded, size: 14, color: TipoColors.muted)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r.translationEn, style: const TextStyle(color: TipoColors.muted, fontSize: 12.5, height: 1.45))),
                    ],
                  ),
                ],
                if (flags.isNotEmpty) ...[
                  const SizedBox(height: Space.sm + 2),
                  Wrap(
                    spacing: Space.xs + 2,
                    runSpacing: Space.xs + 2,
                    children: [
                      for (final f in flags)
                        Tag(
                          label: f.label,
                          icon: f.risk ? Icons.warning_amber_rounded : Icons.check_rounded,
                          color: f.risk ? TipoColors.criticalOnDark : TipoColors.lowOnDark,
                          filled: f.risk,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreDial extends StatelessWidget {
  const _ScoreDial({required this.score, required this.color, required this.label, required this.caption});
  final int score;
  final Color color;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $score out of 100. $caption',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: TipoColors.navyPanel,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: TipoColors.navyLine),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score.clamp(0, 100) / 100),
                  duration: Motion.slow,
                  curve: Motion.curve,
                  builder: (context, v, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(value: v, strokeWidth: 7, color: color, backgroundColor: TipoColors.navyLine, strokeCap: StrokeCap.round),
                      Center(child: Text('${(v * 100).round()}', style: displayStyle(size: 22, color: TipoColors.text))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w700, color: TipoColors.text, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(caption, style: const TextStyle(color: TipoColors.muted, fontSize: 12.5, height: 1.4)),
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

class _CredibilityTab extends StatelessWidget {
  const _CredibilityTab({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    final c = i.credibility;
    final label = c >= 70 ? 'Credible' : c >= 40 ? 'Mixed signals' : 'Low credibility';
    final reasons = [...i.credibilityReasons]..sort((a, b) => reasonTone(a).index.compareTo(reasonTone(b).index));
    return _TabList(
      children: [
        _ScoreDial(
          score: c,
          color: bandColor(credibilityBand(c)),
          label: label,
          caption: 'Verification agent: EXIF time and GPS, BMKG weather for the village, and corroboration across reports.',
        ),
        const SizedBox(height: Space.lg),
        const Eyebrow('Why this credibility'),
        for (final r in reasons) _Reason(text: r, tone: reasonTone(r)),
        if (reasons.isEmpty) const Text('No reasons recorded.', style: TextStyle(color: TipoColors.muted)),
      ],
    );
  }
}

class _PriorityTab extends StatelessWidget {
  const _PriorityTab({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    final factors = priorityFactors(i);
    final damped = i.credibility < 40;
    return _TabList(
      children: [
        _ScoreDial(
          score: i.priorityScore,
          color: bandColor(i.priorityBand),
          label: '${i.priorityBand[0].toUpperCase()}${i.priorityBand.substring(1)} priority',
          caption: damped ? 'Scaled by 0.45 because credibility is under 40.' : 'Weighted sum of the factors below.',
        ),
        const SizedBox(height: Space.lg),
        const Eyebrow('How the score is built'),
        for (final f in factors) _FactorBar(factor: f),
        const SizedBox(height: Space.md),
        const Eyebrow('Why this priority'),
        for (final r in i.priorityReasons) _Reason(text: r, tone: ReasonTone.neutral),
      ],
    );
  }
}

class _FactorBar extends StatelessWidget {
  const _FactorBar({required this.factor});
  final PriorityFactor factor;

  @override
  Widget build(BuildContext context) {
    final max = 100 * factor.weight;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Semantics(
        label: '${factor.label}: ${factor.points.round()} of ${max.round()} points',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(factor.label, style: const TextStyle(color: TipoColors.text, fontSize: 12.5))),
                  Text('${factor.points.round()} / ${max.round()}', style: const TextStyle(color: TipoColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: Space.xs + 1),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: ColoredBox(color: TipoColors.navyLine)),
                      FractionallySizedBox(
                        widthFactor: factor.weight / 0.34,
                        child: Stack(
                          children: [
                            Positioned.fill(child: ColoredBox(color: TipoColors.navyRaised.withValues(alpha: 0.9))),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: factor.value),
                              duration: Motion.slow,
                              curve: Motion.curve,
                              builder: (context, v, _) => FractionallySizedBox(
                                widthFactor: v,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(gradient: LinearGradient(colors: [TipoColors.orange, TipoColors.orangeSoft])),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogisticsTab extends StatelessWidget {
  const _LogisticsTab({required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    final l = i.logistics;
    return _TabList(
      children: [
        Text('First 24 hours for about ${i.peopleAffected} people. Estimates, not orders.', style: const TextStyle(color: TipoColors.muted, fontSize: 12.5)),
        const SizedBox(height: Space.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          childAspectRatio: 2.6,
          children: [
            StatTile(value: '${l.waterLitersPerDay} L', label: 'drinking water / day', icon: Icons.water_drop_rounded, accent: TipoColors.info),
            StatTile(value: '${l.readyMeals}', label: 'ready meals', icon: Icons.restaurant_rounded),
            StatTile(value: '${l.boats}', label: 'rescue boats', icon: Icons.directions_boat_rounded, accent: TipoColors.lowOnDark),
            StatTile(value: '${l.familyKits}', label: 'family kits', icon: Icons.medical_services_rounded, accent: TipoColors.mediumOnDark),
          ],
        ),
        const SizedBox(height: Space.lg),
        const Eyebrow('Teams'),
        if (i.suggestedTeam != null) _TeamRow(team: i.suggestedTeam!, primary: true),
        if (i.standbyTeam != null) ...[const SizedBox(height: Space.sm), _TeamRow(team: i.standbyTeam!, primary: false)],
        if (i.suggestedTeam == null && i.standbyTeam == null) const Text('No team suggested for this ticket.', style: TextStyle(color: TipoColors.muted)),
        if (i.shelter != null) ...[
          const SizedBox(height: Space.lg),
          const Eyebrow('Nearest shelter'),
          _InfoRow(
            icon: Icons.night_shelter_rounded,
            title: i.shelter!.name,
            caption: '${i.shelter!.bedsFree} beds free · ${(i.shelter!.distanceM / 1000).toStringAsFixed(1)} km',
          ),
        ],
      ],
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.team, required this.primary});
  final TeamSuggestion team;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return _InfoRow(
      icon: team.kind == 'boat' ? Icons.directions_boat_rounded : Icons.medical_services_rounded,
      title: team.name,
      caption: '${team.posko} · about ${team.etaMin} min',
      badge: primary ? 'Suggested' : 'Standby',
      accent: primary ? TipoColors.orangeSoft : TipoColors.muted,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.caption, this.badge, this.accent = TipoColors.info});
  final IconData icon;
  final String title;
  final String caption;
  final String? badge;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: TipoColors.navyPanel,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: TipoColors.navyLine),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.sm)),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: TipoColors.text)),
                Text(caption, style: const TextStyle(color: TipoColors.muted, fontSize: 12)),
              ],
            ),
          ),
          if (badge != null) Tag(label: badge!, color: accent),
        ],
      ),
    );
  }
}

class _SitrepTab extends StatelessWidget {
  const _SitrepTab({required this.incident, required this.onOpen});
  final Incident incident;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = incident.sitrepMarkdown.isEmpty ? 'No draft yet.' : incident.sitrepMarkdown;
    return _TabList(
      children: [
        Row(
          children: [
            const Expanded(child: Text('BNPB-style draft, ready to paste.', style: TextStyle(color: TipoColors.muted, fontSize: 12.5))),
            TextButton.icon(onPressed: onOpen, icon: const Icon(Icons.open_in_full_rounded, size: 16), label: const Text('Full page')),
            const SizedBox(width: Space.xs),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(backgroundColor: TipoColors.navyRaised, foregroundColor: TipoColors.text, minimumSize: const Size(0, 40)),
              onPressed: () => copySitrep(context, text),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy sitrep'),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: TipoColors.navyPanel,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: TipoColors.navyLine),
          ),
          child: SelectionArea(child: SitrepBody(markdown: text, compact: true)),
        ),
      ],
    );
  }
}

class _ActionFooter extends StatelessWidget {
  const _ActionFooter({required this.incident, required this.acting, required this.onApprove, required this.onReject, required this.onEdit});
  final Incident incident;
  final bool acting;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    final approved = i.status == 'approved';
    final suspect = isSuspect(i);
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
      decoration: const BoxDecoration(
        color: TipoColors.navyPanel,
        border: Border(top: BorderSide(color: TipoColors.navyLine)),
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: suspect ? TipoColors.navyRaised : TipoColors.orange,
                    foregroundColor: suspect ? TipoColors.orangeSoft : TipoColors.navy,
                    side: suspect ? const BorderSide(color: TipoColors.orangeSoft) : null,
                  ),
                  onPressed: acting || approved ? null : onApprove,
                  icon: acting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: TipoColors.navy))
                      : Icon(approved ? Icons.check_circle_rounded : Icons.campaign_rounded),
                  label: Text(acting ? 'Sending…' : approved ? 'Alert already sent' : 'Approve and send alert'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: TipoColors.navyLine), minimumSize: const Size.fromHeight(44)),
                  onPressed: acting ? null : onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TipoColors.criticalOnDark,
                    side: BorderSide(color: TipoColors.criticalOnDark.withValues(alpha: suspect ? 1 : 0.5)),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: acting || i.status == 'rejected' ? null : onReject,
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Reject'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          const Row(
            children: [
              Icon(Icons.shield_rounded, size: 14, color: TipoColors.muted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'You decide. The model never broadcasts an alert on its own.',
                  style: TextStyle(color: TipoColors.muted, fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
