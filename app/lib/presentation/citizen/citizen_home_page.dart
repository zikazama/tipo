import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import '../state/citizen_providers.dart';
import '../state/providers.dart';
import '../widgets/badges.dart';
import '../widgets/states.dart';
import 'report_progress.dart';

class CitizenHomePage extends ConsumerStatefulWidget {
  const CitizenHomePage({super.key});

  @override
  ConsumerState<CitizenHomePage> createState() => _CitizenHomePageState();
}

class _CitizenHomePageState extends ConsumerState<CitizenHomePage> {
  static const _lat = -6.9755;
  static const _lng = 107.6250;
  var _standby = true;
  var _announced = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendPresence());
  }

  Future<void> _sendPresence() async {
    if (!_standby || _announced) return;
    _announced = true;
    try {
      final reporterId = await ref.read(reporterIdProvider.notifier).ready();
      await ref.read(tipoApiProvider).presence(reporterId: reporterId, lat: _lat, lng: _lng);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final reporter = ref.watch(reporterIdProvider);
    final board = ref.watch(boardProvider);
    final text = Theme.of(context).textTheme;
    final alerts = board.maybeWhen(
      data: (snap) => snap.notifications.where((n) => n.reporterId == reporter && n.type == 'nearby_alert').toList(),
      orElse: () => const <Notice>[],
    );
    return SafeArea(
      child: RefreshIndicator(
        color: TipoColors.orange,
        onRefresh: () async {
          ref.invalidate(bmkgProvider);
          await ref.read(boardProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.xl - 4, Space.md, Space.xl - 4, Space.xxl),
          children: [
            Row(
              children: [
                const Wordmark(),
                const Spacer(),
                if (kIsWeb)
                  IconButton(
                    tooltip: 'Posko console',
                    onPressed: () => context.go('/ops'),
                    icon: const Icon(Icons.space_dashboard_outlined),
                  ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Text('Halo, warga Dayeuhkolot', style: text.titleSmall?.copyWith(color: context.muted)),
            const SizedBox(height: Space.xs),
            Semantics(header: true, child: Text('Lihat tanda bahaya?\nLaporkan ke posko.', style: text.headlineLarge)),
            const SizedBox(height: Space.sm),
            Text('Read the signs. Act first.', style: text.titleSmall?.copyWith(color: context.link)),
            const SizedBox(height: Space.xl),
            _ReportNowButton(onPressed: () => context.push('/report')),
            const SizedBox(height: Space.md),
            Text(
              'Foto, pesan suara, atau beberapa kata sudah cukup. Petugas posko menyetujui setiap peringatan publik.',
              style: text.bodyMedium?.copyWith(color: context.muted),
            ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: Space.xl),
              _AlertBanner(notice: alerts.last, onOpen: () => context.go('/inbox')),
            ],
            const SizedBox(height: Space.xl),
            const _BmkgCard(),
            const SizedBox(height: Space.md),
            _StandbyCard(
              on: _standby,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _standby = value);
                if (value) {
                  _announced = false;
                  _sendPresence();
                }
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
                  return const _InlineNote(
                    icon: Icons.assignment_outlined,
                    text: 'Belum ada laporan dari perangkat ini. Laporan Anda dan statusnya akan muncul di sini.',
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

class _ReportNowButton extends StatelessWidget {
  const _ReportNowButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Lapor sekarang. Report now.',
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
              padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.lg + 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.xl),
                boxShadow: [BoxShadow(color: TipoColors.orange.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: TipoColors.navy, shape: BoxShape.circle),
                    child: const Icon(Icons.add_a_photo_rounded, color: TipoColors.white, size: 28),
                  ),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lapor sekarang', style: displayStyle(size: 24, color: TipoColors.navy, weight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        const Text('Report now', style: TextStyle(color: TipoColors.navy, fontWeight: FontWeight.w600, fontSize: 15)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: TipoColors.navy, size: 28),
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
  const _BmkgCard();

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
        data: (b) {
          final heavy = b.rainMm >= 20;
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
                        child: const Text('Data drill', style: TextStyle(color: TipoColors.muted, fontSize: 11)),
                      ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Icon(heavy ? Icons.thunderstorm_rounded : Icons.cloud_rounded, color: TipoColors.white, size: 44),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(heavy ? 'Hujan lebat' : 'Berawan', style: displayStyle(size: 22, color: TipoColors.white)),
                          Text('${b.weatherEn} · ${b.rainMm.round()} mm / ${b.period}', style: const TextStyle(color: TipoColors.text, fontSize: 13.5)),
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
  const _StandbyCard({required this.on, required this.onChanged});
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
        title: const Text('Siaga di Dayeuhkolot', style: TextStyle(fontWeight: FontWeight.w600)),
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
