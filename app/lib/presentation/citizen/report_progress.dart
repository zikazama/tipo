import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';

enum ProgressState { done, current, waiting, failed }

class ProgressStep {
  const ProgressStep(this.titleId, this.titleEn, this.detail, this.state, this.icon);
  final String titleId;
  final String titleEn;
  final String detail;
  final ProgressState state;
  final IconData icon;
}

/// The five stages a citizen sees: received, verified, merged, triaged, operator decision.
List<ProgressStep> reportProgress(CitizenReport report, Incident? incident) {
  final verified = report.credibility != null;
  final merged = report.incidentId != null;
  final triaged = incident != null && incident.priorityScore > 0;
  final decision = incident?.decision;
  ProgressState at(bool done, bool previousDone) => done ? ProgressState.done : (previousDone ? ProgressState.current : ProgressState.waiting);

  final others = incident == null ? 0 : incident.reportIds.length - 1;
  return [
    const ProgressStep('Diterima', 'Received', 'Laporan sampai di posko.', ProgressState.done, Icons.inbox_rounded),
    ProgressStep(
      'Diverifikasi',
      'Verified',
      verified ? 'Skor kredibilitas ${report.credibility}/100 dari agen verifikasi.' : 'Agen verifikasi sedang memeriksa.',
      at(verified, true),
      Icons.verified_user_rounded,
    ),
    ProgressStep(
      'Digabung',
      'Merged',
      !merged
          ? 'Mencari laporan serupa di sekitar.'
          : others > 0
          ? 'Digabung dengan $others laporan lain tentang kejadian yang sama.'
          : 'Tiket baru dibuka untuk kejadian ini.',
      at(merged, verified),
      Icons.merge_rounded,
    ),
    ProgressStep(
      'Diprioritaskan',
      'Triaged',
      triaged ? 'Prioritas ${bandLabelId(incident.priorityBand)} · skor ${incident.priorityScore}.' : 'Menunggu penilaian prioritas.',
      at(triaged, merged),
      Icons.low_priority_rounded,
    ),
    switch (decision?.action) {
      'approve' => ProgressStep(
        'Disetujui operator',
        'Operator approved',
        decision!.alertSent ? 'Operator posko mengirim peringatan ke warga sekitar.' : 'Operator posko memverifikasi laporan Anda.',
        ProgressState.done,
        Icons.how_to_reg_rounded,
      ),
      'reject' => const ProgressStep(
        'Ditinjau operator',
        'Reviewed, not confirmed',
        'Belum terkonfirmasi. Tidak ada peringatan publik. Dalam bahaya? Telepon 112.',
        ProgressState.failed,
        Icons.how_to_reg_rounded,
      ),
      _ => ProgressStep(
        'Menunggu operator',
        'Waiting for operator',
        'Seorang petugas memutuskan sebelum ada peringatan publik.',
        triaged ? ProgressState.current : ProgressState.waiting,
        Icons.how_to_reg_rounded,
      ),
    },
  ];
}

int stepsDone(List<ProgressStep> steps) => steps.where((s) => s.state == ProgressState.done).length;

String currentLabel(List<ProgressStep> steps) {
  final failed = steps.where((s) => s.state == ProgressState.failed);
  if (failed.isNotEmpty) return failed.first.titleId;
  final current = steps.where((s) => s.state == ProgressState.current);
  if (current.isNotEmpty) return current.first.titleId;
  return steps.lastWhere((s) => s.state == ProgressState.done).titleId;
}
