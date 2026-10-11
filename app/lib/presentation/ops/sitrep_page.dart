import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../state/providers.dart';
import '../widgets/badges.dart';
import '../widgets/states.dart';
import 'ops_widgets.dart';

Future<void> copySitrep(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, 'Sitrep copied', tone: ToastTone.success, detail: 'Paste it into the BPBD / BNPB report channel.');
}

class SitrepPage extends ConsumerWidget {
  const SitrepPage({super.key, required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardProvider);
    return Theme(
      data: opsTheme(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: TipoColors.navy,
          titleSpacing: 0,
          title: const Text('Situation report'),
          leading: IconButton(tooltip: 'Back to the board', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.go('/ops')),
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: TipoColors.navyLine)),
        ),
        body: board.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorState(title: 'The posko API is not responding', message: '$error'),
          data: (snap) {
            final matches = snap.incidents.where((i) => i.id == incidentId);
            if (matches.isEmpty) {
              return EmptyState(
                icon: Icons.description_outlined,
                title: 'That ticket is not on the board',
                body: 'It may have been cleared by a reset. Go back and pick an incident.',
                action: OutlinedButton(onPressed: () => context.go('/ops'), child: const Text('Back to the board')),
              );
            }
            final incident = matches.first;
            final text = incident.sitrepMarkdown.isEmpty ? 'No draft yet.' : incident.sitrepMarkdown;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView(
                  padding: const EdgeInsets.all(Space.xl),
                  children: [
                    Row(
                      children: [
                        PriorityBadge(band: incident.priorityBand, score: incident.priorityScore, large: true),
                        const SizedBox(width: Space.sm),
                        StatusPill(status: incident.status, alertSent: incident.decision?.alertSent ?? false),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => copySitrep(context, text),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy'),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    Text(
                      'BNPB-style draft. The same text is served at /api/incidents/${incident.id}/sitrep.',
                      style: const TextStyle(color: TipoColors.muted),
                    ),
                    const SizedBox(height: Space.lg),
                    Container(
                      padding: const EdgeInsets.all(Space.xl),
                      decoration: BoxDecoration(
                        color: TipoColors.navyPanel,
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(color: TipoColors.navyLine),
                      ),
                      child: SelectionArea(child: SitrepBody(markdown: text)),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Renders the small markdown subset the triage agent writes.
class SitrepBody extends StatelessWidget {
  const SitrepBody({super.key, required this.markdown, this.compact = false});
  final String markdown;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final line in markdown.split('\n')) _SitrepLine(line: line, compact: compact)],
    );
  }
}

class _SitrepLine extends StatelessWidget {
  const _SitrepLine({required this.line, required this.compact});
  final String line;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.sm),
        child: Text(line.substring(2), style: displayStyle(size: compact ? 20 : 28, color: TipoColors.text)),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.md),
        child: Text(line.substring(3), style: const TextStyle(color: TipoColors.orangeSoft, fontWeight: FontWeight.w700)),
      );
    }
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.lg, bottom: Space.xs + 2),
        child: Text(line.substring(4).toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1, fontWeight: FontWeight.w800, color: TipoColors.text)),
      );
    }
    if (line.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7, right: Space.sm),
              child: SizedBox(width: 5, height: 5, child: DecoratedBox(decoration: BoxDecoration(color: TipoColors.orangeSoft, shape: BoxShape.circle))),
            ),
            Expanded(child: _rich(line.substring(2))),
          ],
        ),
      );
    }
    if (line.trim().isEmpty) return const SizedBox(height: Space.xs);
    return Padding(padding: const EdgeInsets.only(bottom: Space.xs), child: _rich(line));
  }

  Widget _rich(String text) {
    final base = TextStyle(fontFamily: bodyFont, height: 1.45, fontSize: compact ? 13 : 14, color: TipoColors.text);
    final parts = text.split('**');
    if (parts.length < 3) return Text(text, style: base);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (var n = 0; n < parts.length; n++)
            TextSpan(text: parts[n], style: n.isOdd ? const TextStyle(fontWeight: FontWeight.w700, color: TipoColors.white) : null),
        ],
      ),
    );
  }
}
