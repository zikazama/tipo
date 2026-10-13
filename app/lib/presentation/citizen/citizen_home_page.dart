import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../domain/citizen_context.dart';
import '../../domain/models.dart';
import '../state/citizen_providers.dart';
import '../state/providers.dart';
import '../widgets/badges.dart';
import '../widgets/citizen_layout.dart';
import '../widgets/states.dart';
import 'report_progress.dart';

class CitizenHomePage extends ConsumerStatefulWidget {
  const CitizenHomePage({super.key});

  @override
  ConsumerState<CitizenHomePage> createState() => _CitizenHomePageState();
}

class _CitizenHomePageState extends ConsumerState<CitizenHomePage> {
  var _standby = true;
  var _announced = false;
  String? _presenceKey;

  Future<void> _sendPresence(CitizenContext ctx) async {
    if (!_standby) return;
    final key = '${ctx.placeShort}:${ctx.lat},${ctx.lng}';
    if (_announced && _presenceKey == key) return;
    _announced = true;
    _presenceKey = key;
    try {
      final reporterId = await ref.read(reporterIdProvider.notifier).ready();
      if (!mounted) return;
      await ref.read(tipoApiProvider).presence(reporterId: reporterId, lat: ctx.lat, lng: ctx.lng);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final reporter = ref.watch(reporterIdProvider);
    final board = ref.watch(boardProvider);
    final text = Theme.of(context).textTheme;
    final narrow = CitizenLayout.isNarrow(context);
    final ctx = board.maybeWhen(
      data: (snap) => CitizenContext.fromScenario(snap.activeScenario),
      orElse: () => CitizenContext.flood,
    );
    ref.listen(boardProvider, (prev, next) {
      final snap = next.value;
      if (snap == null) return;
      _sendPresence(CitizenContext.fromScenario(snap.activeScenario));
    });

    final alerts = board.maybeWhen(
      data: (snap) => snap.notifications.where((n) => n.reporterId == reporter && n.type == 'nearby_alert').toList(),
      orElse: () => const <Notice>[],
    );
    final headlineStyle = CitizenLayout.pageHeadlineStyle(context);

    return SafeArea(
      child: RefreshIndicator(
        color: TipoColors.orange,
        onRefresh: () async {
          ref.invalidate(bmkgProvider);
          await ref.read(boardProvider.notifier).refresh();
        },
        child: ListView(
          padding: CitizenLayout.pagePadding(context).copyWith(top: Space.md),
          children: [
            Row(
              children: [
                Wordmark(compact: narrow),
                const Spacer(),
                if (kIsWeb)
                  IconButton(
                    tooltip: 'Posko console',
                    onPressed: () => context.go('/ops'),
                    icon: const Icon(Icons.space_dashboard_outlined),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Text(ctx.greeting, style: text.titleSmall?.copyWith(color: context.muted, fontSize: narrow ? 13.5 : null)),
            const SizedBox(height: Space.xs),
            Semantics(header: true, child: Text(ctx.headlineId, style: headlineStyle)),
            const SizedBox(height: Space.sm),
            Text('Read the signs. Act first.', style: text.titleSmall?.copyWith(color: context.link, fontSize: narrow ? 13.5 : null)),
            if (ctx.isFire) ...[
              const SizedBox(height: Space.md),
              const _ScenarioChip(
                icon: Icons.local_fire_department_rounded,
                label: 'Drill aktif: karhutla Pelalawan',
                detail: 'Asap, lahan gambut, dan damkar',
              ),
            ],
            const SizedBox(height: Space.lg),
            _ReportNowButton(onPressed: () => context.push('/report'), compact: narrow, fire: ctx.isFire),
            const SizedBox(height: Space.md),
            Text(
              ctx.isFire
                  ? 'Foto asap, pesan suara, atau beberapa kata sudah cukup. Petugas posko menyetujui setiap peringatan publik.'
                  : 'Foto, pesan suara, atau beberapa kata sudah cukup. Petugas posko menyetujui setiap peringatan publik.',
              style: text.bodyMedium?.copyWith(color: context.muted, height: 1.45, fontSize: narrow ? 13.5 : null),
            ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: Space.xl),
              _AlertBanner(notice: alerts.last, onOpen: () => context.go('/inbox')),
            ],
            const SizedBox(height: Space.xl),
            _BmkgCard(preferredAreaKey: ctx.bmkgAreaKey, fireMode: ctx.isFire),
            const SizedBox(height: Space.md),
            _StandbyCard(
              title: ctx.standbyTitle,
              on: _standby,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() {
                  _standby = value;
                  if (value) _announced = false;
                });
                if (value) _sendPresence(ctx);
              },
            ),
            const SizedBox(height: Space.xl),
            SectionTitle(
              'Laporan saya',
              trailing: TextButton(onPressed: () => context.go('/mine'), child: const Text('Lihat semua')),
            ),
            board.when(
              loading: () => const Column(children: [Skeleton(), SizedBox(height: Space.sm), Skeleton()]),
              error: (error, _) => _InlineNote(
                icon: Icons.cloud_off_rounded,
                text: 'Posko belum terhubung. Laporan tetap bisa disiapkan.',
                action: TextButton(onPressed: () => ref.read(boardProvider.notifier).refresh(), child: const Text('Coba lagi')),
              ),
              data: (snap) {
                final mine = snap.reports.where((r) => r.reporterId == reporter).toList().reversed.toList();
                if (mine.isEmpty) {
                  return _InlineNote(
                    icon: Icons.assignment_outlined,
                    text: ctx.isFire
                        ? 'Belum ada laporan dari perangkat ini. Contoh karhutla Segati akan muncul setelah Anda kirim laporan.'
                        : 'Belum ada laporan dari perangkat ini. Laporan Anda dan statusnya akan muncul di sini.',
                  );
                }
                return Column(
                  children: [
                    for (final report in mine.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.sm),
                        child: ReportStatusTile(report: report, incident: _incidentFor(snap, report)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

Incident? _incidentFor(BoardSnapshot snap, CitizenReport report) {
  final match = snap.incidents.where((i) => i.id == report.incidentId);
  return match.isEmpty ? null : match.first;
}

class _ScenarioChip extends StatelessWidget {
  const _ScenarioChip({required this.icon, required this.label, required this.detail});
  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      decoration: BoxDecoration(
        color: TipoColors.orangeTint,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: TipoColors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: TipoColors.orangeInk, size: 20),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: TipoColors.navy, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(detail, style: TextStyle(color: TipoColors.inkSoft, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportNowButton extends StatelessWidget {
  const _ReportNowButton({required this.onPressed, required this.compact, this.fire = false});
  final VoidCallback onPressed;
  final bool compact;
  final bool fire;

  @override
  Widget build(BuildContext context) {
    final title = fire ? 'Lapor karhutla' : 'Lapor sekarang';
    final subtitle = fire ? 'Report peatland fire' : 'Report now';
    return Semantics(
      button: true,
      label: '$title. $subtitle.',
      child: ExcludeSemantics(
        child: Material(
          color: TipoColors.orange,
          borderRadius: BorderRadius.circular(Radii.xl),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.xl),
            onTap: () {
              HapticFeedback.mediumImpact();
              onPressed();
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: compact ? Space.lg : Space.xl, vertical: compact ? Space.lg : Space.lg + 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.xl),
                boxShadow: [BoxShadow(color: TipoColors.orange.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  Container(
                    width: compact ? 48 : 56,
                    height: compact ? 48 : 56,
                    decoration: const BoxDecoration(color: TipoColors.navy, shape: BoxShape.circle),
                    child: Icon(
                      fire ? Icons.local_fire_department_rounded : Icons.add_a_photo_rounded,
                      color: TipoColors.white,
                      size: compact ? 24 : 28,
                    ),
                  ),
                  SizedBox(width: compact ? Space.md : Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: displayStyle(size: compact ? 20 : 22, color: TipoColors.navy, weight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: TextStyle(color: TipoColors.navy, fontWeight: FontWeight.w600, fontSize: compact ? 13.5 : 15)),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Icon(Icons.arrow_forward_rounded, color: TipoColors.navy, size: compact ? 24 : 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.notice, required this.onOpen});
  final Notice notice;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Material(
        color: TipoColors.critical,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: TipoColors.white, size: 30),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PERINGATAN DI SEKITAR ANDA', style: TextStyle(color: TipoColors.white, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(notice.title, style: displayStyle(size: 17, color: TipoColors.white, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      const Text('Dikirim oleh petugas posko · Sent by a posko operator', style: TextStyle(color: TipoColors.white, fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: TipoColors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BmkgCard extends ConsumerWidget {
  const _BmkgCard({required this.preferredAreaKey, required this.fireMode});
  final String preferredAreaKey;
  final bool fireMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brief = ref.watch(bmkgProvider);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        gradient: const LinearGradient(colors: [TipoColors.navy, Color(0xFF153A6B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      padding: const EdgeInsets.all(Space.lg + 2),
      child: brief.when(
        loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
        error: (error, _) => Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: TipoColors.muted),
            const SizedBox(width: Space.md),
            const Expanded(child: Text('Data BMKG belum tersedia. BMKG data unavailable.', style: TextStyle(color: TipoColors.text))),
            TextButton(onPressed: () => ref.invalidate(bmkgProvider), child: const Text('Coba lagi')),
          ],
        ),
        data: (raw) {
          final b = raw.forArea(preferredAreaKey);
          final haze = fireMode || b.fireRisk.isNotEmpty || b.weatherEn.toLowerCase().contains('haze');
          final heavy = !haze && b.rainMm >= 20;
          final titleId = haze ? 'Kabut asap' : heavy ? 'Hujan lebat' : 'Berawan';
          final icon = haze ? Icons.local_fire_department_rounded : heavy ? Icons.thunderstorm_rounded : Icons.cloud_rounded;
          return Semantics(
            container: true,
            label: 'BMKG ${b.area}: ${b.weatherEn}, ${b.rainMm.round()} millimetres in ${b.period}.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('BMKG', style: TextStyle(color: TipoColors.orangeSoft, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(width: Space.sm),
                    Expanded(child: Text('· ${b.area}', style: const TextStyle(color: TipoColors.muted, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    if (b.recorded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: TipoColors.navyLine), borderRadius: BorderRadius.circular(Radii.pill)),
                        child: Text(haze ? 'Drill asap' : 'Data drill', style: const TextStyle(color: TipoColors.muted, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Icon(icon, color: TipoColors.white, size: 44),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titleId, style: displayStyle(size: 22, color: TipoColors.white)),
                          Text(
                            haze
                                ? '${b.weatherEn} · risiko api ${b.fireRisk.isEmpty ? 'tinggi' : b.fireRisk}'
                                : '${b.weatherEn} · ${b.rainMm.round()} mm / ${b.period}',
                            style: const TextStyle(color: TipoColors.text, fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (b.nowcast.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  Container(
                    padding: const EdgeInsets.all(Space.md),
                    decoration: BoxDecoration(color: TipoColors.orange.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.campaign_rounded, color: TipoColors.orangeSoft, size: 20),
                        const SizedBox(width: Space.sm),
                        Expanded(child: Text(b.nowcast, style: const TextStyle(color: TipoColors.text, fontSize: 13, height: 1.4))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StandbyCard extends StatelessWidget {
  const _StandbyCard({required this.title, required this.on, required this.onChanged});
  final String title;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        value: on,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        secondary: Icon(Icons.share_location_rounded, color: context.link),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Terima peringatan sekitar dari posko. Standby for nearby alerts.', style: TextStyle(color: context.muted, fontSize: 13)),
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(border: Border.all(color: context.line), borderRadius: BorderRadius.circular(Radii.lg)),
      child: Row(
        children: [
          Icon(icon, color: context.muted),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: TextStyle(color: context.muted, height: 1.4))),
          ?action,
        ],
      ),
    );
  }
}

/// One report with its place in the five-step pipeline.
class ReportStatusTile extends StatelessWidget {
  const ReportStatusTile({super.key, required this.report, required this.incident});
  final CitizenReport report;
  final Incident? incident;

  @override
  Widget build(BuildContext context) {
    final steps = reportProgress(report, incident);
    final done = stepsDone(steps);
    final failed = steps.any((s) => s.state == ProgressState.failed);
    final finished = done == steps.length;
    final band = finished ? 'low' : failed ? 'critical' : 'high';
    final body = report.text.isEmpty ? report.transcript : report.text;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => context.push('/mine/${report.id}'),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              HazardAvatar(hazard: report.hazardType, band: band, size: 44),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(body.isEmpty ? 'Laporan foto' : body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          Expanded(
                            child: Container(
                              height: 4,
                              margin: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 3),
                              decoration: BoxDecoration(
                                color: steps[i].state == ProgressState.done
                                    ? context.bandFill('low')
                                    : steps[i].state == ProgressState.failed
                                    ? context.bandFill('critical')
                                    : steps[i].state == ProgressState.current
                                    ? TipoColors.orange
                                    : context.line,
                                borderRadius: BorderRadius.circular(Radii.pill),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currentLabel(steps)} · ${timeAgo(report.createdAt)}',
                      style: TextStyle(color: context.bandText(band), fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.muted),
            ],
          ),
        ),
      ),
    );
  }
}
