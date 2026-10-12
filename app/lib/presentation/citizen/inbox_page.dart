import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import '../state/citizen_providers.dart';
import '../state/providers.dart';
import '../widgets/states.dart';

/// Messages the posko sent to this device. In mock mode they arrive through
/// the API inbox; with Firebase configured the same payloads go out over FCM.
class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporter = ref.watch(reporterIdProvider);
    final board = ref.watch(boardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kotak masuk')),
      body: board.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: const [Skeleton(height: 110), SizedBox(height: Space.sm), Skeleton(height: 110)],
        ),
        error: (error, _) => ErrorState(message: 'Pesan belum bisa dimuat. $error', onRetry: () => ref.read(boardProvider.notifier).refresh()),
        data: (snap) {
          final mine = snap.notifications.where((n) => n.reporterId == reporter).toList().reversed.toList();
          if (mine.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Belum ada pesan',
              body: 'No alerts yet. Status laporan dan peringatan dari petugas posko akan muncul di sini. Model AI tidak pernah mengirim peringatan sendiri.',
            );
          }
          return RefreshIndicator(
            color: TipoColors.orange,
            onRefresh: () => ref.read(boardProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(Space.lg),
              itemCount: mine.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: Space.md),
              itemBuilder: (context, index) {
                if (index == mine.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: Text(
                      'Mode demo: pesan masuk lewat kotak masuk aplikasi. Dengan Firebase, pesan yang sama dikirim lewat FCM.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final n = mine[index];
                final match = snap.incidents.where((i) => i.id == n.incidentId);
                return NoticeCard(notice: n, incident: match.isEmpty ? null : match.first);
              },
            ),
          );
        },
      ),
    );
  }
}

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.notice, required this.incident});
  final Notice notice;
  final Incident? incident;

  @override
  Widget build(BuildContext context) {
    final alert = notice.type == 'nearby_alert';
    final verified = notice.type == 'reporter_status' && notice.title.toLowerCase().contains('verified');
    final band = alert ? (incident?.priorityBand == 'critical' || incident == null ? 'critical' : incident!.priorityBand) : (verified ? 'low' : 'medium');
    final fill = context.bandFill(band);
    final (kicker, icon) = alert
        ? ('PERINGATAN SEKITAR · NEARBY ALERT', Icons.warning_amber_rounded)
        : verified
        ? ('STATUS LAPORAN · VERIFIED', Icons.verified_rounded)
        : ('STATUS LAPORAN · REVIEWED', Icons.info_outline_rounded);
    return Semantics(
      container: true,
      label: '$kicker. ${notice.title}. ${notice.body}',
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: alert ? fill.withValues(alpha: context.isDark ? 0.18 : 0.10) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: alert ? fill : context.line, width: alert ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: fill),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(icon, color: context.bandText(band), size: 20),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(kicker, style: TextStyle(color: context.bandText(band), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                            ),
                            Text(timeAgo(notice.createdAt), style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                        Text(notice.title, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: Space.xs),
                        Text(notice.body, style: const TextStyle(height: 1.45)),
                        if (alert) ...[
                          const SizedBox(height: Space.md),
                          Row(
                            children: [
                              Icon(Icons.person_pin_rounded, size: 16, color: context.muted),
                              const SizedBox(width: 6),
                              Expanded(child: Text('Dikirim oleh petugas posko, bukan oleh model AI.', style: Theme.of(context).textTheme.bodySmall)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
