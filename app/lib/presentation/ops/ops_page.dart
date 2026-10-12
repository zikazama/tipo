import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../domain/insights.dart';
import '../../domain/models.dart';
import '../state/providers.dart';
import '../widgets/badges.dart';
import '../widgets/states.dart';
import 'activity_feed.dart';
import 'incident_detail.dart';
import 'incident_queue.dart';
import 'ops_map.dart' deferred as ops_map;
import 'ops_widgets.dart';

enum _Section { board, activity }

enum _Pane { queue, map, detail, activity }

class OpsPage extends ConsumerStatefulWidget {
  const OpsPage({super.key});

  @override
  ConsumerState<OpsPage> createState() => _OpsPageState();
}

class _OpsPageState extends ConsumerState<OpsPage> {
  String? _selectedId;
  String _filter = 'all';
  QueueSort _sort = QueueSort.priority;
  _Section _section = _Section.board;
  _Pane _pane = _Pane.queue;
  _Pane _sidePane = _Pane.detail;
  var _acting = false;
  /// Load flutter_map only after the first board frame (and as a deferred JS/wasm chunk).
  var _mapReady = false;
  static Future<void>? _mapLibrary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapLibrary ??= ops_map.loadLibrary();
      _mapLibrary!.whenComplete(() {
        if (mounted) setState(() => _mapReady = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(boardProvider);
    final width = MediaQuery.sizeOf(context).width;
    final showRail = width >= 760;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (showRail) _Rail(section: _section, onSection: _onRail),
            Expanded(
              child: board.when(
                loading: () => const _Loading(),
                error: (error, _) => ErrorState(
                  title: 'The posko API is not responding',
                  message: 'Start the backend on port 8765, then retry.\n$error',
                  onRetry: () => ref.read(boardProvider.notifier).refresh(),
                ),
                data: (snap) => _board(context, snap, width, showRail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _board(BuildContext context, BoardSnapshot snap, double width, bool rail) {
    final visible = applyQueue(snap.incidents, _filter, _sort);
    final selected = _resolve(visible, snap.incidents);
    final queue = IncidentQueue(
      all: snap.incidents,
      visible: visible,
      selectedId: selected?.id,
      onSelect: _select,
      filter: _filter,
      onFilter: (f) => setState(() => _filter = f),
      sort: _sort,
      onSort: (s) => setState(() => _sort = s),
      replaying: snap.replay.running,
    );
    final map = _mapReady
        ? ops_map.IncidentMap(incidents: snap.incidents, selectedId: selected?.id, onSelect: _select, presence: snap.presence)
        : const ColoredBox(color: TipoColors.navyDeep);
    final detail = IncidentDetail(
      key: ValueKey('detail-${selected?.id}'),
      incident: selected,
      snap: snap,
      acting: _acting,
      mediaUrl: ref.read(tipoApiProvider).mediaUrl,
      onApprove: () => _approve(selected!, snap),
      onReject: () => _reject(selected!),
      onEdit: () => _edit(selected!),
      onOpenSitrep: () => context.go('/ops/sitrep/${selected!.id}'),
    );
    final feed = ActivityFeed(snap: snap, onSelectIncident: _select, dense: true);

    final Widget body;
    if (_section == _Section.activity) {
      body = Row(
        children: [
          Expanded(child: OpsPanel(child: ActivityFeed(snap: snap, onSelectIncident: _select))),
          if (width >= 1100) SizedBox(width: 440, child: detail),
        ],
      );
    } else if (width >= 1240) {
      body = Row(
        children: [
          SizedBox(width: 372, child: queue),
          Expanded(
            child: Column(
              children: [
                Expanded(child: ClipRect(child: map)),
                const Divider(height: 1, color: TipoColors.navyLine),
                SizedBox(height: 248, child: OpsPanel(border: false, child: feed)),
              ],
            ),
          ),
          Container(
            width: 440,
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: TipoColors.navyLine))),
            child: detail,
          ),
        ],
      );
    } else if (width >= 900) {
      body = Row(
        children: [
          SizedBox(width: 340, child: queue),
          Expanded(
            child: Column(
              children: [
                _PaneSwitch(
                  value: _sidePane,
                  options: const [_Pane.detail, _Pane.map, _Pane.activity],
                  onChanged: (p) => setState(() => _sidePane = p),
                ),
                Expanded(
                  child: switch (_sidePane) {
                    _Pane.map => ClipRect(child: map),
                    _Pane.activity => OpsPanel(border: false, child: feed),
                    _ => detail,
                  },
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      body = Column(
        children: [
          _PaneSwitch(value: _pane, options: _Pane.values, onChanged: (p) => setState(() => _pane = p)),
          Expanded(
            child: switch (_pane) {
              _Pane.queue => queue,
              _Pane.map => ClipRect(child: map),
              _Pane.activity => OpsPanel(border: false, child: feed),
              _Pane.detail => detail,
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        _TopBar(
          snap: snap,
          compact: width < 1100,
          showLogo: !rail,
          onReplay: _replay,
          onReplayScenario: _replayScenario,
          onReset: _reset,
        ),
        _ReplayProgress(replay: snap.replay),
        Expanded(child: body),
      ],
    );
  }

  Incident? _resolve(List<Incident> visible, List<Incident> all) {
    if (_selectedId != null) {
      final match = all.where((i) => i.id == _selectedId);
      if (match.isNotEmpty) return match.first;
    }
    if (visible.isNotEmpty) return visible.first;
    return null;
  }

  void _select(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedId = id;
      _pane = _Pane.detail;
      _sidePane = _Pane.detail;
    });
  }

  void _onRail(int index) {
    switch (index) {
      case 0:
        setState(() => _section = _Section.board);
      case 1:
        setState(() => _section = _Section.activity);
      case 2:
        final snap = ref.read(boardProvider).value;
        final target = snap == null ? null : _resolve(applyQueue(snap.incidents, _filter, _sort), snap.incidents);
        if (target == null) {
          showToast(context, 'No incident to report on yet', detail: 'Replay the drill first.');
        } else {
          context.go('/ops/sitrep/${target.id}');
        }
      default:
        context.go('/');
    }
  }

  Future<void> _replay() async {
    final snap = ref.read(boardProvider).value;
    final active = snap?.activeScenario;
    await _replayScenario(active?.id, active);
  }

  Future<void> _replayScenario(String? scenarioId, [ScenarioInfo? info]) async {
    final snap = ref.read(boardProvider).value;
    ScenarioInfo? chosen = info;
    if (chosen == null && scenarioId != null && snap != null) {
      for (final scenario in snap.scenarios) {
        if (scenario.id == scenarioId) {
          chosen = scenario;
          break;
        }
      }
    }
    chosen ??= snap?.activeScenario;
    final title = chosen?.title ?? 'drill';
    final count = chosen?.reports ?? 0;
    final detail = count > 0
        ? '$count reports across app, voice, WhatsApp, and PetaBencana.'
        : 'Reports stream into the posko queue.';
    showToast(context, 'Replaying $title', detail: detail);
    try {
      await ref.read(boardProvider.notifier).replay(scenarioId: scenarioId);
    } catch (error) {
      if (mounted) showToast(context, 'Replay could not start', tone: ToastTone.error, detail: '$error');
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TipoColors.navyPanel,
        title: const Text('Reset the drill?'),
        content: const Text('This clears every report, ticket, and alert on this posko board.', style: TextStyle(color: TipoColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset board')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      setState(() => _selectedId = null);
      await ref.read(boardProvider.notifier).reset();
      if (mounted) showToast(context, 'Board cleared', tone: ToastTone.success);
    } catch (error) {
      if (mounted) showToast(context, 'Reset failed', tone: ToastTone.error, detail: '$error');
    }
  }

  Future<void> _approve(Incident incident, BoardSnapshot snap) async {
    final recipients = nearbyRecipients(incident, snap);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmAlertDialog(incident: incident, recipients: recipients.length),
    );
    if (confirmed != true) return;
    await _decide(
      incident,
      {'action': 'approve', 'send_alert': true, 'note': 'Rescue team dispatched.'},
      success: 'Alert sent to ${recipients.length} nearby device${recipients.length == 1 ? '' : 's'}',
      detail: 'You approved it. The model did not.',
    );
  }

  Future<void> _reject(Incident incident) => _decide(
        incident,
        {'action': 'reject', 'send_alert': false, 'note': 'Not corroborated.'},
        success: 'Ticket rejected',
        detail: 'Only the reporter is told. No public alert.',
      );

  Future<void> _decide(Incident incident, Map<String, dynamic> body, {required String success, String? detail}) async {
    setState(() => _acting = true);
    try {
      await ref.read(tipoApiProvider).decide(incident.id, {...body, 'operator_name': 'Posko operator'});
      await ref.read(boardProvider.notifier).refresh();
      HapticFeedback.mediumImpact();
      if (mounted) showToast(context, success, tone: ToastTone.success, detail: detail);
    } on TipoException catch (error) {
      if (mounted) showToast(context, 'Decision not saved', tone: ToastTone.error, detail: error.message);
    } catch (error) {
      if (mounted) showToast(context, 'Decision not saved', tone: ToastTone.error, detail: '$error');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _edit(Incident incident) async {
    final people = TextEditingController(text: '${incident.peopleAffected}');
    final note = TextEditingController();
    var band = incident.priorityBand;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: TipoColors.navyPanel,
        title: const Text('Edit before you decide'),
        content: SizedBox(
          width: 400,
          child: StatefulBuilder(
            builder: (context, setLocal) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Your edits are logged with the decision and flow into the sitrep.', style: TextStyle(color: TipoColors.muted, fontSize: 13)),
                const SizedBox(height: Space.lg),
                const Eyebrow('Priority'),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final b in const ['critical', 'high', 'medium', 'low'])
                      ButtonSegment(value: b, label: Text('${b[0].toUpperCase()}${b.substring(1)}', style: TextStyle(color: bandColor(b)))),
                  ],
                  selected: {band},
                  onSelectionChanged: (v) => setLocal(() => band = v.first),
                ),
                const SizedBox(height: Space.lg),
                TextField(
                  controller: people,
                  decoration: const InputDecoration(labelText: 'People affected', prefixIcon: Icon(Icons.groups_rounded)),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: Space.md),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Note for the log', prefixIcon: Icon(Icons.notes_rounded))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save edit')),
        ],
      ),
    );
    if (saved != true) return;
    await _decide(
      incident,
      {
        'action': 'edit',
        'priority_band': band,
        'people_affected': int.tryParse(people.text) ?? incident.peopleAffected,
        'note': note.text,
      },
      success: 'Edit saved',
      detail: 'Priority set to $band.',
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.section, required this.onSection});
  final _Section section;
  final ValueChanged<int> onSection;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: TipoColors.navy, border: Border(right: BorderSide(color: TipoColors.navyLine))),
      child: NavigationRail(
        backgroundColor: Colors.transparent,
        selectedIndex: section.index,
        onDestinationSelected: onSection,
        labelType: NavigationRailLabelType.all,
        minWidth: 84,
        indicatorColor: TipoColors.orange.withValues(alpha: 0.2),
        selectedIconTheme: const IconThemeData(color: TipoColors.orangeSoft),
        unselectedIconTheme: const IconThemeData(color: TipoColors.muted),
        selectedLabelTextStyle: const TextStyle(fontFamily: bodyFont, color: TipoColors.text, fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: const TextStyle(fontFamily: bodyFont, color: TipoColors.muted, fontSize: 12, fontWeight: FontWeight.w500),
        leading: const Padding(
          padding: EdgeInsets.only(top: Space.md, bottom: Space.xl),
          child: Tooltip(message: 'TIPO · Read the signs. Act first.', child: TipoLogoMark(size: 44)),
        ),
        destinations: const [
          NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: Text('Board')),
          NavigationRailDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub_rounded), label: Text('Activity')),
          NavigationRailDestination(icon: Icon(Icons.description_outlined), label: Text('Sitrep')),
          NavigationRailDestination(icon: Icon(Icons.phone_android_rounded), label: Text('Citizen')),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.snap,
    required this.compact,
    required this.showLogo,
    required this.onReplay,
    required this.onReplayScenario,
    required this.onReset,
  });
  final BoardSnapshot snap;
  final bool compact;
  final bool showLogo;
  final VoidCallback onReplay;
  final void Function(String? scenarioId, [ScenarioInfo? info]) onReplayScenario;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final open = snap.incidents.where((i) => i.status == 'open').length;
    final critical = snap.incidents.where((i) => i.priorityBand == 'critical' && i.status == 'open' && !isSuspect(i)).length;
    final alerts = snap.notifications.where((n) => n.type == 'nearby_alert').length;
    final r = snap.replay;
    final place = snap.activeScenario?.hazard == 'fire'
        ? 'Posko Pelalawan · Riau'
        : 'Posko Dayeuhkolot · Kab. Bandung';
    final scenarios = snap.scenarios.isNotEmpty
        ? snap.scenarios
        : [
            if (snap.activeScenario != null) snap.activeScenario!,
          ];
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      decoration: const BoxDecoration(color: TipoColors.navy, border: Border(bottom: BorderSide(color: TipoColors.navyLine))),
      child: Row(
        children: [
          Expanded(
            child: ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    if (showLogo)
                      const Wordmark(light: true, compact: true, subtitle: 'Posko Dashboard')
                    else
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Posko Dashboard', style: displayStyle(size: 18, color: TipoColors.text)),
                          Row(
                            children: [
                              const Icon(Icons.place_rounded, size: 13, color: TipoColors.orangeSoft),
                              const SizedBox(width: 3),
                              Text(place, style: const TextStyle(color: TipoColors.muted, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(width: Space.xl),
                    if (!compact) ...[
                      _Kpi(value: '$open', label: 'open', color: TipoColors.text),
                      _Kpi(value: '$critical', label: 'critical', color: TipoColors.criticalOnDark),
                      _Kpi(value: '$alerts', label: 'alerts sent', color: TipoColors.lowOnDark),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          _ReplayPill(replay: r, compact: compact),
          const SizedBox(width: Space.sm),
          if (!compact) ...[
            Tooltip(
              message: 'Agents run in ${snap.mode} mode on ${snap.model}',
              child: Tag(label: '${snap.mode.toUpperCase()} · ${snap.model}', icon: Icons.memory_rounded, color: TipoColors.info),
            ),
            const SizedBox(width: Space.md),
          ],
          compact
              ? IconButton(tooltip: 'Reset the drill', onPressed: r.running ? null : onReset, icon: const Icon(Icons.restart_alt_rounded))
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), side: const BorderSide(color: TipoColors.navyLine)),
                  onPressed: r.running ? null : onReset,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Reset'),
                ),
          const SizedBox(width: Space.sm),
          if (scenarios.length > 1)
            MenuAnchor(
              builder: (context, controller, child) => FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: Space.lg)),
                onPressed: r.running
                    ? null
                    : () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                icon: Icon(r.running ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded, size: 20),
                label: Text(r.running ? 'Replaying…' : compact ? 'Replay' : 'Replay scenario'),
              ),
              menuChildren: [
                for (final scenario in scenarios)
                  MenuItemButton(
                    onPressed: () => onReplayScenario(scenario.id, scenario),
                    leadingIcon: Icon(
                      scenario.hazard == 'fire' ? Icons.local_fire_department_rounded : Icons.flood_rounded,
                      size: 18,
                    ),
                    child: Text('${scenario.title} (${scenario.reports})'),
                  ),
              ],
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: Space.lg)),
              onPressed: r.running ? null : onReplay,
              icon: Icon(r.running ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded, size: 20),
              label: Text(r.running ? 'Replaying…' : compact ? 'Replay' : 'Replay scenario'),
            ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Space.lg),
      child: Semantics(
        label: '$value $label',
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: displayStyle(size: 20, color: color)),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(color: TipoColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplayPill extends StatelessWidget {
  const _ReplayPill({required this.replay, required this.compact});
  final ReplayStatus replay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = replay;
    final done = !r.running && r.ingested >= r.total && r.total > 0;
    final (label, color) = r.running
        ? ('Live replay ${r.ingested}/${r.total}', TipoColors.criticalOnDark)
        : done
            ? ('Drill complete ${r.ingested}/${r.total}', TipoColors.lowOnDark)
            : r.ingested > 0
                ? ('Paused ${r.ingested}/${r.total}', TipoColors.mediumOnDark)
                : ('Ready · ${r.total} reports', TipoColors.muted);
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm - 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  value: r.total == 0 ? 0 : r.ingested / r.total,
                  strokeWidth: 2.6,
                  color: color,
                  backgroundColor: TipoColors.navyLine,
                ),
              ),
              const SizedBox(width: Space.sm),
              Text(compact ? '${r.ingested}/${r.total}' : label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplayProgress extends StatelessWidget {
  const _ReplayProgress({required this.replay});
  final ReplayStatus replay;

  @override
  Widget build(BuildContext context) {
    final value = replay.total == 0 ? 0.0 : replay.ingested / replay.total;
    return AnimatedOpacity(
      duration: Motion.base,
      opacity: replay.running ? 1 : 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: Motion.slow,
        curve: Motion.curve,
        builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 3, color: TipoColors.orange, backgroundColor: TipoColors.navyLine),
      ),
    );
  }
}

class _PaneSwitch extends StatelessWidget {
  const _PaneSwitch({required this.value, required this.options, required this.onChanged});
  final _Pane value;
  final List<_Pane> options;
  final ValueChanged<_Pane> onChanged;

  @override
  Widget build(BuildContext context) {
    (String, IconData) meta(_Pane p) => switch (p) {
          _Pane.queue => ('Queue', Icons.inbox_rounded),
          _Pane.map => ('Map', Icons.map_rounded),
          _Pane.detail => ('Detail', Icons.article_rounded),
          _Pane.activity => ('Agents', Icons.hub_rounded),
        };
    return Container(
      color: TipoColors.navy,
      padding: const EdgeInsets.all(Space.sm),
      child: SegmentedButton<_Pane>(
        showSelectedIcon: false,
        segments: [for (final p in options) ButtonSegment(value: p, icon: Icon(meta(p).$2, size: 18), label: Text(meta(p).$1))],
        selected: {value},
        onSelectionChanged: (v) => onChanged(v.first),
      ),
    );
  }
}

class _ConfirmAlertDialog extends StatelessWidget {
  const _ConfirmAlertDialog({required this.incident, required this.recipients});
  final Incident incident;
  final int recipients;

  @override
  Widget build(BuildContext context) {
    final preview = alertPreview(incident);
    final suspect = isSuspect(incident);
    final reporters = incident.reporterIds.toSet().length;
    return AlertDialog(
      backgroundColor: TipoColors.navyPanel,
      titlePadding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.sm),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: TipoColors.orange.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.md)),
            child: const Icon(Icons.campaign_rounded, color: TipoColors.orangeSoft),
          ),
          const SizedBox(width: Space.md),
          const Expanded(child: Text('Send this alert?')),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Check the wording and reach. Once sent, phones nearby are notified right away.', style: TextStyle(color: TipoColors.muted, fontSize: 13)),
            if (suspect) ...[
              const SizedBox(height: Space.md),
              Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: TipoColors.critical.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: TipoColors.criticalOnDark),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gpp_bad_rounded, color: TipoColors.criticalOnDark),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        'Credibility is ${incident.credibility}/100. The verification agent flagged this as a possible hoax.',
                        style: const TextStyle(color: TipoColors.text, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Space.lg),
            const Eyebrow('Alert preview'),
            Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(
                color: TipoColors.white,
                borderRadius: BorderRadius.circular(Radii.lg),
                boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 6))],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TipoLogoMark(size: 36),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('TIPO · Peringatan posko', style: TextStyle(color: TipoColors.inkSoft, fontSize: 11.5, fontWeight: FontWeight.w600)),
                            Spacer(),
                            Text('now', style: TextStyle(color: TipoColors.inkSoft, fontSize: 11.5)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(preview.title, style: const TextStyle(fontFamily: headingFont, color: TipoColors.navy, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(preview.body, style: const TextStyle(color: TipoColors.navy, fontSize: 12.5, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(child: StatTile(value: '${(nearbyRadiusM / 1000).toStringAsFixed(0)} km', label: 'radius', icon: Icons.radar_rounded)),
                const SizedBox(width: Space.sm),
                Expanded(child: StatTile(value: '$recipients', label: 'devices nearby', icon: Icons.phone_iphone_rounded, accent: TipoColors.info)),
                const SizedBox(width: Space.sm),
                Expanded(child: StatTile(value: '$reporters', label: 'reporters', icon: Icons.mark_email_read_rounded, accent: TipoColors.lowOnDark)),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.xl),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: Text('Send alert to $recipients device${recipients == 1 ? '' : 's'}'),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TipoLogoMark(size: 56),
          SizedBox(height: Space.lg),
          SizedBox(width: 160, child: LinearProgressIndicator(minHeight: 3)),
          SizedBox(height: Space.md),
          Text('Connecting to the posko…', style: TextStyle(color: TipoColors.muted)),
        ],
      ),
    );
  }
}
