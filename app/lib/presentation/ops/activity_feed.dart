import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/insights.dart';
import '../../domain/models.dart';
import '../widgets/states.dart';
import 'ops_widgets.dart';

class AgentEvent {
  const AgentEvent({required this.step, required this.at, this.reportId, this.incidentId, this.channel});
  final AgentStep step;
  final DateTime? at;
  final String? reportId;
  final String? incidentId;
  final String? channel;
}

/// Flattens per-report agent steps and per-incident triage into one stream, newest first.
List<AgentEvent> agentEvents(BoardSnapshot snap) {
  final events = <AgentEvent>[
    for (final r in snap.reports)
      for (final s in r.steps) AgentEvent(step: s, at: r.createdAt, reportId: r.id, incidentId: r.incidentId, channel: r.channel),
    for (final i in snap.incidents)
      for (final s in i.agentTrace.where((s) => s.agent == 'triage')) AgentEvent(step: s, at: i.updatedAt ?? i.createdAt, incidentId: i.id),
  ];
  const order = {'intake': 0, 'verification': 1, 'dedup': 2, 'triage': 3};
  events.sort((a, b) {
    final t = (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0));
    if (t != 0) return t;
    return (order[b.step.agent] ?? 0).compareTo(order[a.step.agent] ?? 0);
  });
  return events;
}

class ActivityFeed extends StatelessWidget {
  const ActivityFeed({super.key, required this.snap, this.onSelectIncident, this.dense = false});
  final BoardSnapshot snap;
  final ValueChanged<String>? onSelectIncident;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final events = agentEvents(snap);
    final counts = {for (final a in agents) a.key: events.where((e) => e.step.agent == a.key).length};
    final models = {for (final e in events) e.step.agent: e.step.model};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaneHeader(
          icon: Icons.hub_rounded,
          title: 'Agent activity',
          caption: snap.replay.running ? 'Live · ADK pipeline is processing the drill' : '${events.length} agent steps · ${snap.mode} mode',
          trailing: snap.replay.running ? const _LiveDot() : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
          child: Row(
            children: [
              for (var n = 0; n < agents.length; n++) ...[
                Expanded(child: _PipelineStage(meta: agents[n], count: counts[agents[n].key] ?? 0, model: models[agents[n].key], dense: dense)),
                if (n < agents.length - 1 && dense)
                  const SizedBox(width: Space.xs)
                else if (n < agents.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.chevron_right_rounded, size: 18, color: TipoColors.navyLine),
                  ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: TipoColors.navyLine),
        Expanded(
          child: events.isEmpty
              ? const EmptyState(
                  icon: Icons.hub_outlined,
                  title: 'Agents are idle',
                  body: 'Each report runs through Intake, Verification, Dedup, and Triage. Steps appear here as they finish.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: Space.xs),
                  itemCount: events.length.clamp(0, 120),
                  itemBuilder: (context, index) => _EventRow(
                    event: events[index],
                    first: index == 0,
                    onTap: events[index].incidentId == null || onSelectIncident == null ? null : () => onSelectIncident!(events[index].incidentId!),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PipelineStage extends StatelessWidget {
  const _PipelineStage({required this.meta, required this.count, required this.model, required this.dense});
  final AgentMeta meta;
  final int count;
  final String? model;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${meta.label}: ${meta.role}${model == null ? '' : ' · $model'}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: Space.sm, vertical: dense ? 6 : Space.sm),
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: meta.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(meta.icon, size: 16, color: meta.color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: TipoColors.text)),
                  if (!dense)
                    Text(model ?? meta.role, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: TipoColors.muted)),
                ],
              ),
            ),
            Text('$count', style: TextStyle(fontFamily: headingFont, fontSize: 13, fontWeight: FontWeight.w700, color: meta.color)),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.first, this.onTap});
  final AgentEvent event;
  final bool first;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = agentMeta(event.step.agent);
    final source = event.reportId == null ? event.incidentId ?? '' : '${event.reportId} · ${channelLabel(event.channel ?? '')}';
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: meta.color.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(meta.icon, size: 15, color: meta.color),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(meta.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: meta.color)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(source, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: TipoColors.muted)),
                      ),
                      const SizedBox(width: 6),
                      Text(timeAgo(event.at), style: const TextStyle(fontSize: 11, color: TipoColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(event.step.summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: TipoColors.text, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (!first) return row;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${event.reportId}-${event.step.agent}-${event.incidentId}'),
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow,
      curve: Motion.curve,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, -8 * (1 - t)), child: child)),
      child: row,
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Live',
      child: FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: TipoColors.criticalOnDark, shape: BoxShape.circle)),
      ),
    );
  }
}
