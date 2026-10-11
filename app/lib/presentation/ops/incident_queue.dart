import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import '../widgets/badges.dart';
import '../widgets/states.dart';
import 'incident_map.dart' show isSuspect;
import 'ops_widgets.dart';

enum QueueSort { priority, credibility, reports, newest }

extension QueueSortLabel on QueueSort {
  String get label => switch (this) {
        QueueSort.priority => 'Priority',
        QueueSort.credibility => 'Credibility',
        QueueSort.reports => 'Reports',
        QueueSort.newest => 'Newest',
      };
}

const queueFilters = [('all', 'All'), ('critical', 'Critical'), ('high', 'High'), ('unconfirmed', 'Unconfirmed')];

List<Incident> applyQueue(List<Incident> all, String filter, QueueSort sort) {
  final list = switch (filter) {
    'all' => [...all],
    'unconfirmed' => all.where(isSuspect).toList(),
    _ => all.where((i) => i.priorityBand == filter && !isSuspect(i)).toList(),
  };
  int newest(Incident a, Incident b) => (b.updatedAt ?? b.createdAt ?? DateTime(0)).compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0));
  list.sort(switch (sort) {
    QueueSort.priority => (a, b) => b.priorityScore.compareTo(a.priorityScore),
    QueueSort.credibility => (a, b) => b.credibility.compareTo(a.credibility),
    QueueSort.reports => (a, b) => b.reportIds.length.compareTo(a.reportIds.length),
    QueueSort.newest => newest,
  });
  return list;
}

class IncidentQueue extends StatelessWidget {
  const IncidentQueue({
    super.key,
    required this.all,
    required this.visible,
    required this.selectedId,
    required this.onSelect,
    required this.filter,
    required this.onFilter,
    required this.sort,
    required this.onSort,
    required this.replaying,
  });
  final List<Incident> all;
  final List<Incident> visible;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final String filter;
  final ValueChanged<String> onFilter;
  final QueueSort sort;
  final ValueChanged<QueueSort> onSort;
  final bool replaying;

  int _count(String f) => applyQueue(all, f, QueueSort.priority).length;

  @override
  Widget build(BuildContext context) {
    final open = all.where((i) => i.status == 'open').length;
    return OpsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaneHeader(
            icon: Icons.inbox_rounded,
            title: 'Incident queue',
            caption: '$open awaiting decision · ${all.length} total',
            trailing: PopupMenuButton<QueueSort>(
              tooltip: 'Sort incidents',
              initialValue: sort,
              onSelected: onSort,
              color: TipoColors.navyRaised,
              itemBuilder: (context) => [
                for (final s in QueueSort.values)
                  PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Icon(s == sort ? Icons.check_rounded : Icons.sort_rounded, size: 18, color: s == sort ? TipoColors.orangeSoft : TipoColors.muted),
                        const SizedBox(width: Space.sm),
                        Text(s.label),
                      ],
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_vert_rounded, size: 18, color: TipoColors.orangeSoft),
                    const SizedBox(width: 4),
                    Text(sort.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: TipoColors.orangeSoft)),
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.md),
            child: Row(
              children: [
                for (final f in queueFilters) ...[
                  _FilterChip(label: f.$2, count: _count(f.$1), selected: filter == f.$1, warn: f.$1 == 'unconfirmed', onTap: () => onFilter(f.$1)),
                  const SizedBox(width: Space.xs),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: TipoColors.navyLine),
          Expanded(
            child: visible.isEmpty
                ? (replaying && all.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(Space.lg),
                        children: const [Skeleton(height: 104), SizedBox(height: Space.sm), Skeleton(height: 104), SizedBox(height: Space.sm), Skeleton(height: 104)],
                      )
                    : EmptyState(
                        icon: all.isEmpty ? Icons.waves_rounded : Icons.filter_alt_off_rounded,
                        title: all.isEmpty ? 'Queue is clear' : 'Nothing matches this filter',
                        body: all.isEmpty
                            ? 'Replay the Dayeuhkolot flood drill from the top bar, or wait for a citizen report.'
                            : 'Switch back to All to see every open ticket.',
                      ))
                : ListView.separated(
                    padding: const EdgeInsets.all(Space.md),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                    itemBuilder: (context, index) {
                      final incident = visible[index];
                      return IncidentCard(
                        key: ValueKey(incident.id),
                        incident: incident,
                        selected: incident.id == selectedId,
                        onTap: () => onSelect(incident.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap, this.warn = false});
  final String label;
  final int count;
  final bool selected;
  final bool warn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = warn ? TipoColors.criticalOnDark : TipoColors.orange;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label, $count',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? accent.withValues(alpha: 0.18) : TipoColors.navyRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.pill),
            side: BorderSide(color: selected ? accent : TipoColors.navyLine),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? TipoColors.text : TipoColors.muted)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: TipoColors.navyDeep.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? accent : TipoColors.muted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IncidentCard extends StatelessWidget {
  const IncidentCard({super.key, required this.incident, required this.selected, required this.onTap});
  final Incident incident;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = incident;
    final suspect = isSuspect(i);
    final band = suspect ? 'critical' : i.priorityBand;
    final edge = suspect ? TipoColors.criticalOnDark : bandColor(i.priorityBand);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        decoration: BoxDecoration(
          color: selected ? TipoColors.navyRaised : (suspect ? const Color(0xFF2A1A28) : TipoColors.navy),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: selected ? TipoColors.orange : (suspect ? TipoColors.criticalOnDark.withValues(alpha: 0.7) : TipoColors.navyLine),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: TipoColors.orange.withValues(alpha: 0.18), blurRadius: 18)] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    margin: const EdgeInsets.symmetric(vertical: Space.md),
                    decoration: BoxDecoration(color: edge, borderRadius: const BorderRadius.horizontal(right: Radius.circular(4))),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HazardAvatar(hazard: i.hazardType, band: band, size: 36),
                              const SizedBox(width: Space.sm + 2),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(i.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: headingFont, fontWeight: FontWeight.w600, fontSize: 14, color: TipoColors.text, height: 1.25)),
                                    const SizedBox(height: 2),
                                    Text(i.placeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: TipoColors.muted)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              PriorityBadge(band: i.priorityBand, score: i.priorityScore),
                            ],
                          ),
                          if (suspect) ...[
                            const SizedBox(height: Space.sm),
                            Wrap(
                              spacing: Space.xs + 2,
                              runSpacing: Space.xs,
                              children: [
                                const Tag(label: 'Possible hoax', icon: Icons.warning_amber_rounded, color: TipoColors.criticalOnDark, filled: true),
                                CredibilityBadge(score: i.credibility),
                              ],
                            ),
                          ],
                          const SizedBox(height: Space.sm + 2),
                          Row(
                            children: [
                              CredibilityMeter(score: i.credibility, width: 56),
                              const SizedBox(width: Space.md),
                              const Icon(Icons.forum_rounded, size: 14, color: TipoColors.muted),
                              const SizedBox(width: 4),
                              Text('${i.reportIds.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TipoColors.text)),
                              const SizedBox(width: Space.md),
                              const Icon(Icons.schedule_rounded, size: 14, color: TipoColors.muted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  timeAgo(i.updatedAt ?? i.createdAt).isEmpty ? 'now' : timeAgo(i.updatedAt ?? i.createdAt),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: TipoColors.muted),
                                ),
                              ),
                              const Spacer(),
                              if (i.status != 'open') StatusPill(status: i.status, alertSent: i.decision?.alertSent ?? false),
                              if (i.status == 'open' && i.updatesSinceDecision > 0)
                                Tag(label: '+${i.updatesSinceDecision} new', color: TipoColors.orangeSoft),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
