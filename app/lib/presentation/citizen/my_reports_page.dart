import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../domain/insights.dart';
import '../state/providers.dart';
import '../widgets/states.dart';
import 'citizen_home_page.dart';
import 'report_progress.dart';

class MyReportsPage extends ConsumerWidget {
  const MyReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporter = ref.watch(reporterIdProvider);
    final board = ref.watch(boardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan saya')),
      body: board.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: const [Skeleton(height: 96), SizedBox(height: Space.sm), Skeleton(height: 96), SizedBox(height: Space.sm), Skeleton(height: 96)],
        ),
        error: (error, _) => ErrorState(message: 'Laporan belum bisa dimuat. $error', onRetry: () => ref.read(boardProvider.notifier).refresh()),
        data: (snap) {
          final mine = snap.reports.where((r) => r.reporterId == reporter).toList().reversed.toList();
          if (mine.isEmpty) {
            return EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Belum ada laporan',
              body: 'No reports from this device yet. Setiap laporan yang Anda kirim akan muncul di sini dengan statusnya.',
              action: FilledButton.icon(onPressed: () => context.push('/report'), icon: const Icon(Icons.add_a_photo_rounded), label: const Text('Lapor sekarang')),
            );
          }
          return RefreshIndicator(
            color: TipoColors.orange,
            onRefresh: () => ref.read(boardProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(Space.lg),
              itemCount: mine.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
              itemBuilder: (context, index) {
                final report = mine[index];
                final match = snap.incidents.where((i) => i.id == report.incidentId);
                return ReportStatusTile(report: report, incident: match.isEmpty ? null : match.first);
              },
            ),
          );
        },
      ),
    );
  }
}

class ReportStatusPage extends ConsumerWidget {
  const ReportStatusPage({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Beranda', icon: const Icon(Icons.close_rounded), onPressed: () => context.go('/')),
        title: const Text('Status laporan'),
      ),
      body: board.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(message: '$error', onRetry: () => ref.read(boardProvider.notifier).refresh()),
        data: (snap) {
          final reportMatches = snap.reports.where((r) => r.id == reportId);
          if (reportMatches.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Laporan tidak ditemukan',
              body: 'This report is not on the current board. Kirim ulang atau putar ulang skenario.',
            );
          }
          final report = reportMatches.first;
          final incidentMatches = snap.incidents.where((i) => i.id == report.incidentId);
          final incident = incidentMatches.isEmpty ? null : incidentMatches.first;
          final steps = reportProgress(report, incident);
          final original = report.transcript.isEmpty ? report.text : report.transcript;
          final english = report.translationEn;
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.xl - 4, Space.xs, Space.xl - 4, Space.xxl),
            children: [
              const _SentHero(),
              const SizedBox(height: Space.xl),
              if (original.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(report.audioUrl != null || report.audioFile != null ? Icons.record_voice_over_rounded : Icons.chat_bubble_outline_rounded, size: 18, color: context.link),
                            const SizedBox(width: Space.sm),
                            Text(
                              report.language == 'su' ? 'Sundanese' : report.language == 'jv' ? 'Javanese' : languageLabel(report.language),
                              style: TextStyle(color: context.link, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                        Text('“$original”', style: text.titleLarge?.copyWith(height: 1.35)),
                        if (english.isNotEmpty && english != original) ...[
                          const SizedBox(height: Space.md),
                          const Divider(),
                          const SizedBox(height: Space.md),
                          Text('ENGLISH RENDERING', style: text.labelSmall?.copyWith(color: context.muted)),
                          const SizedBox(height: Space.xs),
                          Text(english, style: text.bodyLarge?.copyWith(color: context.muted)),
                          const SizedBox(height: Space.xs),
                          Text('Diterjemahkan oleh agen intake', style: text.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: Space.xl),
              const SectionTitle('Perjalanan laporan'),
              _Timeline(steps: steps),
              if (report.credibility != null && report.reasons.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                Card(
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(),
                      leading: Icon(Icons.fact_check_rounded, color: context.link),
                      title: Text('Credibility ${report.credibility}/100', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Mengapa skor ini? · Why this score', style: TextStyle(color: context.muted, fontSize: 12.5)),
                      childrenPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
                      children: [
                        for (final r in report.reasons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(padding: const EdgeInsets.only(top: 7), child: Icon(Icons.circle, size: 6, color: context.muted)),
                                const SizedBox(width: Space.sm),
                                Expanded(child: Text(r, style: const TextStyle(height: 1.4))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Space.lg),
              const _SafetyCard(),
              const SizedBox(height: Space.lg),
              Text(
                'An operator decides before anyone nearby is alerted. The model does not broadcast on its own.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => context.go('/inbox'), icon: const Icon(Icons.notifications_rounded), label: const Text('Kotak masuk'))),
                  const SizedBox(width: Space.md),
                  Expanded(child: FilledButton.icon(onPressed: () => context.go('/'), icon: const Icon(Icons.home_rounded), label: const Text('Beranda'))),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SentHero extends StatelessWidget {
  const _SentHero();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: Motion.slow,
            curve: Curves.elasticOut,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: context.bandFill('low'), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: TipoColors.white, size: 38),
            ),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Laporan terkirim', style: text.headlineMedium),
                Text('Report sent. Terima kasih, posko sudah menerimanya.', style: text.bodyMedium?.copyWith(color: context.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});
  final List<ProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++) _TimelineRow(step: steps[i], last: i == steps.length - 1, index: i),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.last, required this.index});
  final ProgressStep step;
  final bool last;
  final int index;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (step.state) {
      ProgressState.done => (context.bandFill('low'), Icons.check_rounded),
      ProgressState.current => (TipoColors.orange, Icons.more_horiz_rounded),
      ProgressState.failed => (context.bandFill('critical'), Icons.priority_high_rounded),
      ProgressState.waiting => (context.line, step.icon),
    };
    final active = step.state != ProgressState.waiting;
    final stateWord = switch (step.state) {
      ProgressState.done => 'selesai',
      ProgressState.current => 'sedang berjalan',
      ProgressState.failed => 'perlu perhatian',
      ProgressState.waiting => 'menunggu',
    };
    return Semantics(
      label: '${step.titleId}, ${step.titleEn}, $stateWord. ${step.detail}',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 260 + index * 90),
          curve: Motion.curve,
          builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: active ? color : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
                        child: Icon(icon, size: 18, color: active ? TipoColors.white : context.muted),
                      ),
                      if (!last)
                        Expanded(
                          child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: step.state == ProgressState.done ? color : context.line),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: last ? 0 : Space.lg, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: step.titleId, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                              TextSpan(text: '  ${step.titleEn}', style: TextStyle(color: context.muted, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(step.detail, style: TextStyle(color: active ? null : context.muted, height: 1.4, fontSize: 13.5)),
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

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    const tips = [
      (Icons.terrain_rounded, 'Pindah ke tempat yang lebih tinggi.'),
      (Icons.power_off_rounded, 'Matikan listrik jika air masuk rumah.'),
      (Icons.groups_rounded, 'Dahulukan lansia, anak, dan ibu hamil.'),
      (Icons.call_rounded, 'Darurat jiwa? Telepon 112.'),
    ];
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: TipoColors.orange.withValues(alpha: context.isDark ? 0.14 : 0.10), borderRadius: BorderRadius.circular(Radii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sambil menunggu', style: Theme.of(context).textTheme.titleMedium),
          Text('While you wait', style: TextStyle(color: context.muted, fontSize: 12.5)),
          const SizedBox(height: Space.md),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(
                children: [
                  Icon(t.$1, size: 20, color: context.link),
                  const SizedBox(width: Space.md),
                  Expanded(child: Text(t.$2)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
